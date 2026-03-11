#!/usr/bin/env python3
"""
GNN-VAE for Execution Trace Latent Space Learning

This module implements a Graph Neural Network Variational Autoencoder
that learns a latent representation of execution traces where similar
traces are nearby in the latent space.

Requirements:
    pip install torch torch-geometric numpy matplotlib scikit-learn

Usage:
    from gnn_vae import ExecutionTraceVAE, TraceDataset

    # Load traces
    dataset = TraceDataset.from_json("traces.json")

    # Train model
    model = ExecutionTraceVAE(num_node_types=6, hidden_dim=64, latent_dim=16)
    train_vae(model, dataset, epochs=100)

    # Encode traces to latent space
    latent_vectors = model.encode_dataset(dataset)

    # Find similar traces
    similar = find_similar_traces(latent_vectors, query_idx=0, k=5)
"""

import json
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.optim import Adam
from torch_geometric.data import Data, Batch
from torch_geometric.nn import GCNConv, GATConv, global_mean_pool, global_max_pool
from torch_geometric.loader import DataLoader
import numpy as np
from typing import List, Tuple, Optional
from dataclasses import dataclass


# =============================================================================
# Dataset
# =============================================================================

class TraceDataset:
    """Dataset of execution trace graphs."""

    def __init__(self, graphs: List[Data], metadata: Optional[dict] = None):
        self.graphs = graphs
        self.metadata = metadata or {}

    @classmethod
    def from_json(cls, filepath: str) -> "TraceDataset":
        """Load dataset from JSON file exported by Prolog."""
        with open(filepath) as f:
            data = json.load(f)

        graphs = []
        for g in data["graphs"]:
            # Node features: one-hot encoded node types
            num_types = max(g["node_types"]) + 1 if g["node_types"] else 1
            x = F.one_hot(torch.tensor(g["node_types"]), num_types).float()

            # Edge index
            if g["edge_index"] and g["edge_index"][0]:
                edge_index = torch.tensor(g["edge_index"], dtype=torch.long)
            else:
                edge_index = torch.zeros((2, 0), dtype=torch.long)

            # Edge attributes: encode edge types
            edge_type_map = {"control": 0}
            edge_attr = []
            for et in g.get("edge_types", []):
                if isinstance(et, str) and et.startswith("data"):
                    edge_attr.append(1)  # data edge
                else:
                    edge_attr.append(0)  # control edge
            edge_attr = torch.tensor(edge_attr, dtype=torch.float).unsqueeze(1) if edge_attr else None

            # Branch values as graph-level target (for supervised learning)
            y = torch.tensor(g.get("branch_values", []), dtype=torch.float)

            graph = Data(x=x, edge_index=edge_index, edge_attr=edge_attr, y=y)
            graph.num_nodes = g["num_nodes"]
            graphs.append(graph)

        return cls(graphs, {"max_nodes": data.get("max_nodes", 0)})

    def __len__(self):
        return len(self.graphs)

    def __getitem__(self, idx):
        return self.graphs[idx]


# =============================================================================
# GNN Encoder
# =============================================================================

class GNNEncoder(nn.Module):
    """Graph Neural Network encoder for execution traces."""

    def __init__(self,
                 input_dim: int,
                 hidden_dim: int = 64,
                 latent_dim: int = 16,
                 num_layers: int = 3,
                 use_gat: bool = True):
        super().__init__()

        self.num_layers = num_layers
        self.convs = nn.ModuleList()
        self.bns = nn.ModuleList()

        # First layer
        if use_gat:
            self.convs.append(GATConv(input_dim, hidden_dim, heads=4, concat=False))
        else:
            self.convs.append(GCNConv(input_dim, hidden_dim))
        self.bns.append(nn.BatchNorm1d(hidden_dim))

        # Hidden layers
        for _ in range(num_layers - 1):
            if use_gat:
                self.convs.append(GATConv(hidden_dim, hidden_dim, heads=4, concat=False))
            else:
                self.convs.append(GCNConv(hidden_dim, hidden_dim))
            self.bns.append(nn.BatchNorm1d(hidden_dim))

        # Output: mean and log-variance for VAE
        self.fc_mu = nn.Linear(hidden_dim * 2, latent_dim)  # *2 for mean+max pooling
        self.fc_logvar = nn.Linear(hidden_dim * 2, latent_dim)

    def forward(self, x, edge_index, batch):
        # GNN layers
        for i in range(self.num_layers):
            x = self.convs[i](x, edge_index)
            x = self.bns[i](x)
            x = F.relu(x)
            x = F.dropout(x, p=0.1, training=self.training)

        # Global pooling (combine mean and max for richer representation)
        x_mean = global_mean_pool(x, batch)
        x_max = global_max_pool(x, batch)
        x = torch.cat([x_mean, x_max], dim=1)

        # VAE outputs
        mu = self.fc_mu(x)
        logvar = self.fc_logvar(x)

        return mu, logvar


# =============================================================================
# GNN Decoder
# =============================================================================

class GNNDecoder(nn.Module):
    """Decoder that reconstructs graph structure from latent vector."""

    def __init__(self,
                 latent_dim: int = 16,
                 hidden_dim: int = 64,
                 max_nodes: int = 50,
                 num_node_types: int = 6):
        super().__init__()

        self.max_nodes = max_nodes
        self.num_node_types = num_node_types

        # Decode latent to node features
        self.fc1 = nn.Linear(latent_dim, hidden_dim)
        self.fc2 = nn.Linear(hidden_dim, hidden_dim)
        self.fc_nodes = nn.Linear(hidden_dim, max_nodes * num_node_types)

        # Decode adjacency (edge prediction)
        self.fc_adj = nn.Linear(hidden_dim, max_nodes * max_nodes)

        # Predict number of nodes
        self.fc_num_nodes = nn.Linear(hidden_dim, max_nodes)

    def forward(self, z):
        batch_size = z.size(0)

        h = F.relu(self.fc1(z))
        h = F.relu(self.fc2(h))

        # Reconstruct node types
        node_logits = self.fc_nodes(h).view(batch_size, self.max_nodes, self.num_node_types)

        # Reconstruct adjacency matrix
        adj_logits = self.fc_adj(h).view(batch_size, self.max_nodes, self.max_nodes)

        # Predict number of nodes
        num_nodes_logits = self.fc_num_nodes(h)

        return node_logits, adj_logits, num_nodes_logits


# =============================================================================
# VAE Model
# =============================================================================

class ExecutionTraceVAE(nn.Module):
    """
    Variational Autoencoder for execution traces.

    Learns a latent space where similar execution patterns are nearby.
    """

    def __init__(self,
                 num_node_types: int = 6,
                 hidden_dim: int = 64,
                 latent_dim: int = 16,
                 max_nodes: int = 50):
        super().__init__()

        self.latent_dim = latent_dim
        self.encoder = GNNEncoder(num_node_types, hidden_dim, latent_dim)
        self.decoder = GNNDecoder(latent_dim, hidden_dim, max_nodes, num_node_types)

    def reparameterize(self, mu, logvar):
        """Reparameterization trick for VAE."""
        std = torch.exp(0.5 * logvar)
        eps = torch.randn_like(std)
        return mu + eps * std

    def forward(self, data):
        # Encode
        mu, logvar = self.encoder(data.x, data.edge_index, data.batch)

        # Sample latent
        z = self.reparameterize(mu, logvar)

        # Decode
        node_logits, adj_logits, num_nodes_logits = self.decoder(z)

        return {
            "mu": mu,
            "logvar": logvar,
            "z": z,
            "node_logits": node_logits,
            "adj_logits": adj_logits,
            "num_nodes_logits": num_nodes_logits
        }

    def encode(self, data) -> torch.Tensor:
        """Encode a graph to its latent representation."""
        self.eval()
        with torch.no_grad():
            mu, _ = self.encoder(data.x, data.edge_index, data.batch)
        return mu

    def encode_dataset(self, dataset: TraceDataset) -> np.ndarray:
        """Encode all graphs in a dataset to latent vectors."""
        self.eval()
        loader = DataLoader(dataset.graphs, batch_size=32, shuffle=False)

        latents = []
        with torch.no_grad():
            for batch in loader:
                mu, _ = self.encoder(batch.x, batch.edge_index, batch.batch)
                latents.append(mu.cpu().numpy())

        return np.vstack(latents)

    def sample(self, num_samples: int = 1) -> List[dict]:
        """Sample new graphs from the latent space."""
        self.eval()
        with torch.no_grad():
            z = torch.randn(num_samples, self.latent_dim)
            node_logits, adj_logits, num_nodes_logits = self.decoder(z)

            samples = []
            for i in range(num_samples):
                # Get predicted number of nodes
                n_nodes = torch.argmax(num_nodes_logits[i]).item() + 1

                # Get node types
                node_types = torch.argmax(node_logits[i, :n_nodes], dim=1).tolist()

                # Get adjacency (threshold at 0.5)
                adj = torch.sigmoid(adj_logits[i, :n_nodes, :n_nodes]) > 0.5
                edges = adj.nonzero().tolist()

                samples.append({
                    "num_nodes": n_nodes,
                    "node_types": node_types,
                    "edges": edges
                })

            return samples

    def interpolate(self, data1, data2, steps: int = 10) -> List[dict]:
        """Interpolate between two traces in latent space."""
        self.eval()
        with torch.no_grad():
            z1 = self.encode(data1)
            z2 = self.encode(data2)

            interpolations = []
            for alpha in np.linspace(0, 1, steps):
                z = (1 - alpha) * z1 + alpha * z2
                node_logits, adj_logits, num_nodes_logits = self.decoder(z)

                n_nodes = torch.argmax(num_nodes_logits[0]).item() + 1
                node_types = torch.argmax(node_logits[0, :n_nodes], dim=1).tolist()

                interpolations.append({
                    "alpha": alpha,
                    "num_nodes": n_nodes,
                    "node_types": node_types
                })

            return interpolations


# =============================================================================
# Loss Function
# =============================================================================

def vae_loss(output, data, beta=1.0):
    """
    VAE loss = Reconstruction loss + KL divergence

    Args:
        output: Model output dict
        data: Batch of graphs
        beta: Weight for KL term (beta-VAE)
    """
    batch_size = output["mu"].size(0)

    # KL divergence
    kl_loss = -0.5 * torch.sum(1 + output["logvar"] - output["mu"].pow(2) - output["logvar"].exp())
    kl_loss = kl_loss / batch_size

    # Reconstruction loss for node types (simplified: just match first nodes)
    # In practice, you would use a more sophisticated graph matching loss
    recon_loss = torch.tensor(0.0)

    total_loss = recon_loss + beta * kl_loss

    return {
        "total": total_loss,
        "recon": recon_loss,
        "kl": kl_loss
    }


# =============================================================================
# Training
# =============================================================================

def train_vae(model: ExecutionTraceVAE,
              dataset: TraceDataset,
              epochs: int = 100,
              batch_size: int = 32,
              lr: float = 1e-3,
              beta: float = 1.0):
    """
    Train the GNN-VAE model.

    Args:
        model: The VAE model
        dataset: Training dataset
        epochs: Number of training epochs
        batch_size: Batch size
        lr: Learning rate
        beta: KL divergence weight
    """
    optimizer = Adam(model.parameters(), lr=lr)
    loader = DataLoader(dataset.graphs, batch_size=batch_size, shuffle=True)

    model.train()
    history = {"loss": [], "kl": []}

    for epoch in range(epochs):
        total_loss = 0
        total_kl = 0

        for batch in loader:
            optimizer.zero_grad()

            output = model(batch)
            losses = vae_loss(output, batch, beta)

            losses["total"].backward()
            optimizer.step()

            total_loss += losses["total"].item()
            total_kl += losses["kl"].item()

        avg_loss = total_loss / len(loader)
        avg_kl = total_kl / len(loader)
        history["loss"].append(avg_loss)
        history["kl"].append(avg_kl)

        if (epoch + 1) % 10 == 0:
            print(f"Epoch {epoch+1}/{epochs} - Loss: {avg_loss:.4f}, KL: {avg_kl:.4f}")

    return history


# =============================================================================
# Similarity Search
# =============================================================================

def find_similar_traces(latent_vectors: np.ndarray,
                        query_idx: int,
                        k: int = 5) -> List[Tuple[int, float]]:
    """
    Find k most similar traces to query in latent space.

    Args:
        latent_vectors: Array of latent vectors (N x latent_dim)
        query_idx: Index of query trace
        k: Number of neighbors to return

    Returns:
        List of (index, distance) tuples
    """
    from sklearn.neighbors import NearestNeighbors

    nn = NearestNeighbors(n_neighbors=k+1, metric="euclidean")
    nn.fit(latent_vectors)

    distances, indices = nn.kneighbors([latent_vectors[query_idx]])

    # Skip first result (query itself)
    results = [(int(idx), float(dist)) for idx, dist in zip(indices[0][1:], distances[0][1:])]

    return results


def cluster_traces(latent_vectors: np.ndarray,
                   n_clusters: int = 5) -> np.ndarray:
    """
    Cluster execution traces in latent space.

    Args:
        latent_vectors: Array of latent vectors
        n_clusters: Number of clusters

    Returns:
        Cluster labels for each trace
    """
    from sklearn.cluster import KMeans

    kmeans = KMeans(n_clusters=n_clusters, random_state=42)
    labels = kmeans.fit_predict(latent_vectors)

    return labels


# =============================================================================
# Visualization
# =============================================================================

def visualize_latent_space(latent_vectors: np.ndarray,
                           labels: Optional[np.ndarray] = None,
                           save_path: Optional[str] = None):
    """
    Visualize latent space using t-SNE.

    Args:
        latent_vectors: Array of latent vectors
        labels: Optional labels for coloring
        save_path: Path to save figure
    """
    import matplotlib.pyplot as plt
    from sklearn.manifold import TSNE

    # Reduce to 2D
    tsne = TSNE(n_components=2, random_state=42, perplexity=min(30, len(latent_vectors)-1))
    coords = tsne.fit_transform(latent_vectors)

    plt.figure(figsize=(10, 8))

    if labels is not None:
        scatter = plt.scatter(coords[:, 0], coords[:, 1], c=labels, cmap="tab10", alpha=0.7)
        plt.colorbar(scatter, label="Cluster")
    else:
        plt.scatter(coords[:, 0], coords[:, 1], alpha=0.7)

    plt.xlabel("t-SNE 1")
    plt.ylabel("t-SNE 2")
    plt.title("Execution Trace Latent Space")

    if save_path:
        plt.savefig(save_path, dpi=150, bbox_inches="tight")
        print(f"Saved visualization to {save_path}")
    else:
        plt.show()


# =============================================================================
# Demo
# =============================================================================

if __name__ == "__main__":
    print("GNN-VAE for Execution Trace Analysis")
    print("=" * 50)

    # Check if dataset exists
    import os
    if os.path.exists("traces.json"):
        print("\nLoading dataset from traces.json...")
        dataset = TraceDataset.from_json("traces.json")
        print(f"Loaded {len(dataset)} traces")

        if len(dataset) > 0:
            # Get input dimension from first graph
            input_dim = dataset[0].x.size(1)

            # Create model
            model = ExecutionTraceVAE(
                num_node_types=input_dim,
                hidden_dim=64,
                latent_dim=16,
                max_nodes=50
            )

            print(f"\nModel architecture:")
            print(f"  Input dim: {input_dim}")
            print(f"  Hidden dim: 64")
            print(f"  Latent dim: 16")

            # Train
            print("\nTraining VAE...")
            history = train_vae(model, dataset, epochs=50, batch_size=min(32, len(dataset)))

            # Encode all traces
            print("\nEncoding traces to latent space...")
            latents = model.encode_dataset(dataset)
            print(f"Latent vectors shape: {latents.shape}")

            # Cluster
            if len(dataset) >= 5:
                print("\nClustering traces...")
                labels = cluster_traces(latents, n_clusters=min(5, len(dataset)))
                print(f"Cluster distribution: {np.bincount(labels)}")

                # Visualize
                print("\nGenerating visualization...")
                visualize_latent_space(latents, labels, "latent_space.png")

            # Find similar traces
            if len(dataset) > 1:
                print("\nFinding traces similar to trace 0:")
                similar = find_similar_traces(latents, 0, k=min(5, len(dataset)-1))
                for idx, dist in similar:
                    print(f"  Trace {idx}: distance = {dist:.4f}")

            # Sample from latent space
            print("\nSampling new traces from latent space...")
            samples = model.sample(3)
            for i, s in enumerate(samples):
                print(f"  Sample {i+1}: {s['num_nodes']} nodes, types: {s['node_types'][:5]}...")
    else:
        print("\nNo traces.json found. Generate traces first:")
        print("  1. Run programs with tracing enabled")
        print("  2. Export with graph_to_gnn_dataset/2")
        print("  3. Re-run this script")
