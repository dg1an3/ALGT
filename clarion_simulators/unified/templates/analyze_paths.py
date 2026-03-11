#!/usr/bin/env python3
"""
Execution Path Analysis Script
Generated from Clarion simulator trace

This script demonstrates how to:
1. Load the execution graph
2. Fit probabilistic models to observed paths
3. Sample new paths from the posterior
4. Estimate path coverage
"""

import json
import numpy as np

# Load graph data
with open("graph.json") as f:
    graph = json.load(f)

print(f"Loaded graph with {graph['num_nodes']} nodes, {graph['num_edges']} edges")
print(f"Branch nodes: {len(graph['branch_nodes'])}")

# Extract branch decisions from observed executions
# In practice, you would collect these from multiple traced runs
branch_nodes = graph["branch_nodes"]
n_branches = len(branch_nodes)

print(f"\nBranch conditions:")
for b in branch_nodes:
    print(f"  Node {b['node']}: {b['condition']} -> {b['value']}")

# Option 1: Use PyMC for Bayesian inference
def fit_pymc_model(observed_paths):
    """
    Fit a PyMC model to observed execution paths.

    observed_paths: list of lists, each inner list is [0/1] for each branch
    """
    try:
        import pymc as pm
        import arviz as az

        observed = np.array(observed_paths)
        n_obs, n_branches = observed.shape

        with pm.Model() as model:
            # Prior on branch probabilities
            branch_probs = pm.Beta("branch_probs", alpha=1, beta=1, shape=n_branches)

            # Likelihood
            pm.Bernoulli("obs", p=branch_probs, observed=observed)

            # Sample
            trace = pm.sample(2000, return_inferencedata=True)

        # Summarize posterior
        print("\nPosterior branch probabilities:")
        summary = az.summary(trace, var_names=["branch_probs"])
        print(summary)

        return trace
    except ImportError:
        print("PyMC not installed. Install with: pip install pymc arviz")
        return None

# Option 2: Use Stan via CmdStanPy
def fit_stan_model(observed_paths):
    """
    Fit a Stan model to observed execution paths.
    """
    try:
        import cmdstanpy

        observed = np.array(observed_paths)
        n_obs, n_branches = observed.shape

        model = cmdstanpy.CmdStanModel(stan_file="model.stan")

        data = {
            "N_branches": n_branches,
            "N_observations": n_obs,
            "observed_paths": observed.tolist()
        }

        fit = model.sample(data=data, chains=4, iter_sampling=1000)

        print("\nStan fit summary:")
        print(fit.summary())

        # Get sampled paths
        sampled = fit.stan_variable("sampled_path")
        print(f"\nSampled {len(sampled)} paths from posterior")

        return fit
    except ImportError:
        print("CmdStanPy not installed. Install with: pip install cmdstanpy")
        return None

# Option 3: Simple frequentist estimate
def estimate_branch_probs(observed_paths):
    """
    Simple maximum likelihood estimate of branch probabilities.
    """
    observed = np.array(observed_paths)
    probs = observed.mean(axis=0)

    print("\nMLE branch probabilities:")
    for i, p in enumerate(probs):
        print(f"  Branch {i}: P(true) = {p:.3f}")

    return probs

# Generate synthetic observations for demo
# In practice, these would come from traced executions
def generate_synthetic_observations(n_obs, branch_probs):
    """Generate synthetic path observations."""
    return np.random.binomial(1, branch_probs, size=(n_obs, len(branch_probs)))

# Demo
if __name__ == "__main__":
    # Use observed values from the trace if available
    if branch_nodes:
        # Single observation from trace
        observed_values = [1 if b["value"] else 0 for b in branch_nodes]
        print(f"\nObserved path from trace: {observed_values}")

        # For demo: generate more synthetic observations
        # Assume true probabilities are close to observed
        true_probs = np.array([0.7 if v else 0.3 for v in observed_values])
        synthetic_obs = generate_synthetic_observations(50, true_probs)

        # Add the real observation
        all_obs = np.vstack([observed_values, synthetic_obs])

        print(f"\nUsing {len(all_obs)} observations (1 real + {len(synthetic_obs)} synthetic)")

        # Estimate probabilities
        estimate_branch_probs(all_obs)

        # Uncomment to run full Bayesian inference:
        # fit_pymc_model(all_obs)
        # fit_stan_model(all_obs)
    else:
        print("No branch nodes found in graph")
