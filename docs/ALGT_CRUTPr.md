# Dosimetrist Workspace 2.0 Algorithm Verification

## Code Review / Unit Test Procedure (CRUTPr)

**Document:** TH 75.000020, Revision A1
**Date:** 07/15/2003
**Product:** COHERENCE Dosimetrist Workspace 2.0 (Siemens Medical Solutions)

> **Revision History:** This document was developed through four revisions (crutpr.doc through crutpr4.doc). This markdown consolidates the final revision (crutpr4), which includes DRR Calculation (Section 4.2.12), degenerate geometry definitions, IVT Risk Analysis references, and the Prolog translation appendix. Earlier revisions progressively added verification conditions, Prolog predicate mappings, and formalized test procedures.
>
> **Note on equations:** The original document contained Microsoft Equation Editor objects. These have been reconstructed as LaTeX based on the surrounding mathematical context. Placeholders are noted where the original equation content could not be fully reconstructed.

---

## Table of Contents

1. [Introduction](#1-introduction)
   - 1.1 [Purpose](#11-purpose)
   - 1.2 [Scope](#12-scope)
   - 1.3 [Definitions, Acronyms, and Abbreviations](#13-definitions-acronyms-and-abbreviations)
   - 1.4 [References](#14-references)
2. [Code Review](#2-code-review)
3. [Test Description](#3-test-description)
   - 3.1 [Test Object](#31-test-object)
   - 3.2 [Test Environment](#32-test-environment)
   - 3.3 [Tools Used](#33-tools-used)
   - 3.4 [Test Start Criteria](#34-test-start-criteria)
   - 3.5 [Test Stop Criteria](#35-test-stop-criteria)
   - 3.6 [Non-testable Units](#36-non-testable-units)
4. [Test Procedure](#4-test-procedure)
   - 4.2.1 [Contouring](#421-contouring)
   - 4.2.2 [Mesh Generation](#422-mesh-generation)
   - 4.2.3 [Mesh Planar Intersection](#423-mesh-planar-intersection)
   - 4.2.4 [2D Margin](#424-2d-margin)
   - 4.2.5 [3D Margin](#425-3d-margin)
   - 4.2.6 [Isodensity Extraction](#426-isodensity-extraction)
   - 4.2.7 [Beam SSD Calculation](#427-beam-ssd-calculation)
   - 4.2.8 [Beam Volume Generation](#428-beam-volume-generation)
   - 4.2.9 [Beam Volume Planar Intersection](#429-beam-volume-planar-intersection)
   - 4.2.10 [Beam Central Axis / Isocenter Calculation](#4210-beam-central-axis--isocenter-calculation)
   - 4.2.11 [Structure Projection](#4211-structure-projection)
   - 4.2.12 [DRR Calculation](#4212-drr-calculation)
5. [Defects Handling](#5-defects-handling)
6. [Test Results](#6-test-results)
7. [Appendices](#7-appendices)
   - 7.1.1 [Test Data](#711-test-data)
   - 7.1.2 [Translation of Verification Conditions to Prolog Code](#712-translation-of-verification-conditions-to-prolog-code)

---

## 1. Introduction

### 1.1 Purpose

The purpose of this procedure is to support the code review and unit testing of the hazard-identified algorithms in the COHERENCE Dosimetrist 2.0 Workspace. This is in addition to the unit tests specified in the Dosimetrist Workspace 2.0 CRUTPr.

### 1.2 Scope

The scope of these tests is to verify the correct behavior of hazard-identified algorithms that are part of COHERENCE Dosimetrist 2.0 Workspace. Basic unit testing is covered by [1] and is not covered by these tests.

### 1.3 Definitions, Acronyms, and Abbreviations

#### Terms

| Term | Definition |
|------|------------|
| central axis | The line containing both the position of a beam's source and the isocenter |
| facet | A triangular structuring element oriented in 3-dimensions |
| Degenerate line segment | A line segment with end points that coincide (zero length) |
| Degenerate facet | A facet with vertices that coincide (zero area) |
| IEC coordinate systems | A group of coordinate systems that describe the possible positions and movements of the treatment machine; an international standard maintained by the IEC (International Electrotechnical Commission). See [3] for more information. |
| Isocenter | The rotational center of the treatment machine |
| isocentric plane | The plane containing the isocenter, perpendicular to the central axis |
| Isodensity surface | A surface defined on a continuous scalar field for which the value of the field is constant |
| Mesh | A closed surface in 3-dimensions defined by a set of adjacent facets |
| point set | A (usually infinite) set of points on a topological space |
| scalar field | A function mapping vector values to scalar values |

#### Abbreviations

| Abbreviation | Definition |
|---|---|
| BEV | Beam's Eye View |
| BLD | Beam-Limiting Device |
| DCG | Definite Clause Grammar |
| DICOM | Digital Imaging Communication in Medicine |
| IEC | International Electrotechnical Commission |
| MPR | Multi-Planar Reformatted [Image] |
| SAD | Source to Axis Distance |
| SBLDD | Source to Beam Limiting Device Distance |
| SID | Source to Image plane Distance |
| SSD | Source to Skin Distance |
| VRML | Virtual Reality Markup Language |

#### Symbols

| Symbol | Definition |
|---|---|
| $d(v, P)$ | Function representing minimum Euclidian distance from point $v$ to point set $P$ |
| $\mathcal{F}(\mathbb{R}^3)$ | Set of all non-degenerate facets on $\mathbb{R}^3$ |
| $\mathcal{T}(\mathbb{R}^3)$ | Set of all planes on $\mathbb{R}^3$ |
| $\mathcal{L}(\mathbb{R}^3)$ | Set of all lines on $\mathbb{R}^3$ |
| $\mathcal{S}(\mathbb{R}^3)$ | Set of all non-degenerate line segments on $\mathbb{R}^3$ |
| $A(P)$ | Signed area of polygon: $A(P) = \frac{1}{2} \sum (x_1 y_2 - x_2 y_1)$ where the sum is over all pairs of consecutive vertices $V_1$ and $V_2$ of the polygon |

### 1.4 References

| # | Document Name | Document # | Revision |
|---|---|---|---|
| [1] | Dosimetrist WS 2.0 CRUTPr | 75.000016 | A |
| [2] | Dosimetrist WS 2.0 UIArchConfig SWDS | 13.000011 | A |
| [3] | Dosimetrist WS 2.0 Coordinate Transformation SWDS | 11.000204 | A |
| [4] | IVT Risk Analysis | | R1.0 |
| [5] | IVT Hazard Test Specification | | R1.0 |
| [6] | The Prolog Language. W.F. Clocksin, C.S. Mellish. | Book Reference | 4th Ed., Springer-Verlag, 1994. |

---

## 2. Code Review

The code review procedure is described in [1].

### 2.1 Completeness

Not applicable.

### 2.2 Code Review Process Description

Not applicable.

---

## 3. Test Description

### 3.1 Test Object

The test objects are located in ClearCase in the VSIMSRC VOB, in the VsimAlgorithms subsystem of the Main Backend component (`/Backend/Algorithms/src`). For more information on the application architecture, please see [2].

### 3.2 Test Environment

The test environment consists of a set of test drivers that are responsible for reading the input objects (from the Syngo database), applying the appropriate algorithms, and exporting both the input objects and output objects, along with any additional information to files in the appropriate format.

The primary verification activity is performed by a small expert system implemented in Prolog. Prolog was chosen because it can be used to concisely represent sets of logical conditions that must be satisfied by the algorithm inputs/outputs in order for the algorithm to be correct. This is consistent with the verification conditions that are represented here in the form of statements of predicate logic.

The targets of the verification are imported into the test environment, which is an open source Prolog environment developed at the University of Amsterdam (SWI Prolog, www.swi-prolog.org). The imports are done using a set of DCG rules, and then predefined verification predicates are asserted on the imported objects. The results are output and captured to a text file for inclusion in the final test report.

### 3.3 Tools Used

In addition to the SWI Prolog environment, certain file formats are used to transfer data from the test drivers to the test environment. The file formats for export of data to the test environment are as follows:

1. For contours and polygons in 3-dimensions: text files using the Nuages input format.
2. For meshes: text files using Nuages output format (subset of VRML 1.0).
3. For other parameters: text files with one parameter on each line, in the form `name = value`.
4. For images: raw pixel format converted from DICOM images using the DicomEdit utility. The spatial information for the images will be transferred as parameters via format 3.

The file formats are defined within the Prolog test environment using DCG rules.

### 3.4 Test Start Criteria

The algorithmic tests begin concurrent with the start of integration testing.

### 3.5 Test Stop Criteria

The algorithmic tests end when the performance is to within acceptable limits, as defined within this document. Any deviations will be documented in the final test report.

### 3.6 Non-testable Units

Not applicable.

---

## 4. Test Procedure

### 4.1 Informal Test Procedures

Not applicable.

### 4.2 Formal Test Cases and Procedures

---

### 4.2.1 Contouring

**Table 1. ALGT_CONTOURING Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1028 | Mistreatment, dose to wrong location | The 3D structure produced from user drawn contours is not correct (e.g. wrong position, orientation, shape) due to an algorithm error. | SW Design: derive spatial position of contours from spatial information of the original image. |
| HZFS64 | | | When creating contours, contour positions shall be derived directly from the image plane information for the base CT image. |

The primary function of contouring involves converting image coordinates to space coordinates in the DICOM patient coordinate system, and vice versa. The conversion uses the spatial information encoded in the original images to compute the position of the contours relative to the original images.

Verification of contour placement is facilitated by being able to relate some feature of the image to the contour vertices. For this purpose, the isodensity test (described in 4.2.6) is ideal, as it tests for the presence of a threshold crossing at the point of each vertex in the contour.

**Table 2. ALGT_CONTOURING Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_CONTOURING | |
| **Purpose:** Verifies contour position encoding | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Original CT scan in DICOM format. Threshold value | |
| Algorithm Output Objects: Contour(s) from isodensity in DICOM format | |
| **Test Steps:** | |
| Generate an ROI consisting of contour(s) on a single image plane, using the isodensity function with a specified threshold value. Export the single image and the structure set as DICOM file. Copy to 'temp' directory. Run 'ALGT_ISODENSITY' source. Specify CT image filename, structure set image file name, ROI number, and threshold value. Specify any testing parameters. | Test completes successfully. Statistics on test objects and test results are captured in log file. |

---

### 4.2.2 Mesh Generation

**Table 3. ALGT_MESH_GEN Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1030 | Mistreatment, dose to wrong location | The 3D structure produced from user drawn contours is not correct (e.g. wrong position, orientation, shape) due to an algorithm error. | Code Review and Unit Test the structure meshing algorithm. |
| HZFS31 | | | As the user creates contours of a structure, the existing contours are interpolated to create a 3D mesh. The entire CT slices that fall between the contour planes get automatically filled by the interpolation. A structure is a 3D entity, so even a single contour results in a 3D structure. |
| HZRA1034 | Mistreatment, dose to wrong location | The beam shape in the beams eye view does not correspond to the MLC shape as displayed | SW Design: display MPR view of intersection of beam shape wrt structures, as an independent means of visualizing the beam shape. |
| HZFS57 | | | Every MPR will display the cross section with the structure. The appearance of the structure on the MPR segments is governed by the structure display properties. |

The mesh generation algorithm produces a surface $M$ from a collection of closed curves in the form of point sets $\{P_i\}$ that lie on parallel planes. The resulting surface must satisfy a positional condition, a volumetric condition, and a consistency condition.

**Positional condition** — all points on the original polygons are also part of the mesh:

$$\forall P_i, \forall v \in P_i : d(v, M) < \epsilon \qquad (1)$$

**Volumetric condition** — the volume of the mesh should be approximately equal to the slab volume of the original polygons:

$$V(M) \approx \sum_i A(P_i) \cdot t_i \qquad (2)$$

where $A(P_i)$ is the total area of polygons on plane $i$, and $t_i$ is the slice thickness of plane $i$.

**Consistency condition** — the mesh forms a closed, oriented surface. This is tested by ensuring, for each facet, that each pair of consecutive vertices also appears as consecutive vertices in an adjacent facet. That the surface is oriented is verified by ensuring that the vertices in the adjacent facet are in the opposite order from the current facet.

**Table 4. ALGT_MESH_GEN Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_MESH_GEN | |
| **Purpose:** Verifies the mesh generation algorithm | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Contours. | |
| Algorithm Output Objects: Mesh(es). | |
| **Test Steps:** | |
| Run 'ALGT_MESH_GEN' source. Specify ROI in Syngo database (LOID and ROI number). Test driver is executed to output contours and meshes. Test conditions are exercised on resulting objects. | Test completes successfully. Statistics on test objects and test results are captured in log file. |

---

### 4.2.3 Mesh Planar Intersection

**Table 5. ALGT_MESH_PLANE_INTERSECTION Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1034 | Mistreatment, dose to wrong location | The beam shape in the beams eye view does not correspond to the MLC shape as displayed | SW Design: display MPR view of intersection of beam shape wrt structures, as an independent means of visualizing the beam shape. |
| HZFS57 | | | Every MPR will display the cross section with the structure. The appearance of the structure on the MPR segments is governed by the structure display properties. |
| HZFS16 | | | The intersection of the beam with the MPR plane will be illustrated on the MPR image. Different methods may be used to display the beam of the MPR image. This will be controlled by the beam display properties. |

The intersection of a mesh $M$ with a plane $T$ is the point set $P$:

$$P = \{ v \in \mathbb{R}^3 : v \in M \wedge v \in T \} \qquad (3)$$

Given an algorithm that produces output $P'$, we need a computable predicate that asserts $P' = P$. A test for intersection memberships based on (3) creates a necessary but not sufficient condition, specifically:

$$\forall v \in P' : v \in M \wedge v \in T \qquad (4)$$

The membership tests in (4) imply only that $P' \subseteq P$ because of the possibility that some of the points in $P$ will not be contained in $P'$.

An additional volumetric condition can be added to satisfy $P' = P$. Let $\{P'_i\}$ be the intersections on a series of uniformly spaced planes parallel to and including $T$, spanning a region that completely contains $M$. Then the volume of the stack of intersections is:

$$V = \sum_i A(P'_i) \cdot s \qquad (5)$$

where $A(P'_i)$ is the area of $P'_i$ and $s$ is the minimum distance from the first plane to the last. As the number of planes increases, this volume approaches the volume of the original mesh $M$:

$$\lim_{s \to 0} V = V(M) \qquad (6)$$

Applying the volumetric condition to a stack of computed intersections $\{P'_i\}$, and combining with the membership condition (3), results in the verification condition asserting the correctness of all solutions $P'_i$. To implement a computable predicate, a suitable finite $s$ is selected and the volume equality restriction is relaxed to within an appropriate tolerance. As $s$ becomes smaller, the tolerance must be increased to account for the additional error.

**Table 6. ALGT_MESH_PLANE_INTERSECTION Verification Conditions**

| Verification condition | Prolog predicate/arity |
|---|---|
| $P' = P$ (combined) | `ok_mesh_plane_intersect/5` |
| $\forall v \in P' : v \in M \wedge v \in T$ | `ok_mesh_plane_intersect_pos/5` |
| $V \approx V(M)$ | `ok_mesh_plane_intersect_volume/3` |

**Table 7. ALGT_MESH_PLANE_INTERSECTION Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_MESH_PLANE_INTERSECTION | |
| **Purpose:** Verifies the mesh / plane intersection | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Mesh(s) representing structure in VRML format. Plane positions (a sequence of uniformly spaced planes). | |
| Algorithm Output Objects: Polygons on planes | |
| **Test Steps:** | |
| Run 'ALGT_MESH_PLANE_INTERSECTION' source. Specify ROI in Syngo database (LOID and ROI number). Specify offset and plane normal orientation. Test driver is executed to output contours and meshes. Test conditions are exercised on resulting objects. | Test completes successfully. Statistics on test objects and test results are captured in log file. |

---

### 4.2.4 2D Margin

**Table 8. ALGT_MARGIN2D Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1031 | Mistreatment, dose to wrong location | Wrong 2D margin applied to structure set due to software error. | SW Design: immediately display result of margin action to user. |
| HZFS56 | | | To add a specified margin to a contour, the contour must first be selected. Pressing the "Margin" button the "Contour" tab or the menu entry adds a pre-specified margin to the contour. It is action button. The button is ENABLED only when one and only one contour is selected. The user may enter the amount of margin. Upon adding margin, grown up contour becomes selected. Old contour vanishes. Merging due to adding margin: If new grown up contour overlaps with any other contour on the same image plane, and of the same structure, then loop removal and merging takes place. |

The 2D margin is obtained by dilating a region $R$ on $\mathbb{R}^2$. The dilated region $R'$ for a margin size $r$ is the result of forming the union of all ball sets $B_r$ translated by members of $R$:

$$R' = R \oplus B_r = \bigcup_{v \in R} \{ v + b : b \in B_r \} \qquad (7)$$

The ball set $B_r$ is defined:

$$B_r = \{ v \in \mathbb{R}^2 : \|v\| \leq r \} \qquad (8)$$

Given an algorithm that produces $P'$, the boundary of the dilated region, the verification condition is that the minimum distance for all points in $P'$ to $P$ is $r$:

$$\forall v \in P' : d(v, P) \approx r \qquad (9)$$

Likewise, all points on $P$ must be at least a distance of $r$ from $P'$:

$$\forall v \in P : d(v, P') \geq r \qquad (10)$$

An additional area condition is added to ensure the polygon is expanded:

$$A(P') > A(P) \qquad (11)$$

Because $P'$ lies outside $P$, it is sufficient to take the minimum distance to $\partial R$, the boundary of $R$.

**Table 9. ALGT_MARGIN2D Verification Conditions**

| Verification condition | Prolog predicate/arity |
|---|---|
| $\forall v \in P' : d(v, P) \approx r$ | `ok_margin2d/4` |
| $\forall v \in P : d(v, P') \geq r$ | |
| $A(P') > A(P)$ | |

**Table 10. ALGT_MARGIN2D Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_MARGIN2D | |
| **Purpose:** Verifies the 2D margin (dilation) algorithm | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Original polygon in text format. Margin size. | |
| Algorithm Output Objects: Expanded polygon(s) in text format. | |
| **Test Steps:** | |
| Run 'ALGT_MARGIN2D' source. Specify ROI in Syngo database (LOID and ROI number). Specify plane position and margin value. Test driver is executed to output contours and meshes. Test conditions are exercised on resulting objects. | Test completes successfully. Statistics on test objects and test results are captured in log file. |

---

### 4.2.5 3D Margin

**Table 11. ALGT_MARGIN3D Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1039 | Mistreatment, dose to wrong location | "ADD MARGIN 3D" function produces incorrect margin due to algorithm error. | Code Review and Unit Test for 3D Margin code. |
| HZFS26 | | | The user may add a margin to a 3D structure. Pressing the "3D Margin" in the "Auto" tab of the "Localization" mode brings up a dialog for adding 3D margin to the selected structure. This dialog provides: A list of structures; a value field for isotropic margin; six value fields for anisotropic margin in each of the six anatomical directions (superior/inferior, anterior/posterior, right/left). The selected structure will be enlarged by the specified margins in all directions, using 3D morphological operations. |

The 3D margin is obtained by either dilating or eroding a region $R$ on $\mathbb{R}^3$. The dilation for a margin size $r$ is the 3-dimensional version of equation (7). Erosion results from negating the dilation of the negation of $R$, in other words:

$$R \ominus B_r = \overline{\bar{R} \oplus B_r} \qquad (12)$$

The verification condition for both dilation and erosion is analogous to the 2D case. The conditions in Table 12 are for the erosion — dilation reverses the sign of the margin and the inequality.

**Table 12. ALGT_MARGIN3D Verification Conditions**

| Verification condition | Prolog predicate/arity |
|---|---|
| $\forall v \in M' : d(v, M) \approx r$ | `ok_margin3d/4` |
| $\forall v \in M : d(v, M') \geq r$ | |
| $V(M') \gtrless V(M)$ (direction depends on dilation/erosion) | |

**Table 13. ALGT_MARGIN3D Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_MARGIN3D | |
| **Purpose:** Verifies the 3D margin (dilation or erosion) algorithm | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Original mesh in VRML format. Signed margin size. | |
| Algorithm Output Objects: Expanded mesh(s) in VRML format. | |
| **Test Steps:** | |
| Run 'ALGT_MARGIN3D' source. Specify ROI in Syngo database (LOID and ROI number). Specify plane position and margin value. Test driver is executed to output contours and meshes. Test conditions are exercised on resulting objects. | Test completes successfully. Statistics on test objects and test results are captured in log file. |

---

### 4.2.6 Isodensity Extraction

**Table 14. ALGT_ISODENSITY Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1003 | General Mistreatment and/or Physical Injury | Skin surface modeled incorrectly due to algorithm error. | SW Design: provide interactive feedback of skin surface model |
| HZFS7 | | | The "Isodensity" button in the "Auto" tab of the localization enables the user to create structures by assigning a threshold value. All the voxels in the CT data with HU in the range of defined thresholds will be considered as object. The largest contour on the active slice shall be taken as the contour participating in the formation of the structure set. |

Given an image scalar field $I(x,y)$, the isocurve for a single threshold value $\tau$ is:

$$M = \{ v \in \mathbb{R}^2 : I(v) = \tau \} \qquad (13)$$

where $M$ is a closed curve. Given an algorithm that produces a closed curve $M'$, the condition $M' = M$ can be asserted for a set of linear paths $\{l_j\}$ across the image. For each linear path, a crossing set $C_j$ is defined:

$$C_j = \{ v \in l_j : I(v) = \tau \} \qquad (14)$$

Then the positional correctness for the computed surface (along line $l_j$) is defined by the assertion:

$$\forall v \in C_j : d(v, M') < \epsilon \qquad (15)$$

The crossing sets are extracted for all lines corresponding to the scan rows and columns of the image.

An additional volumetric condition can be defined. If $\tau$ is a lower threshold, the area contained by the isocurve is defined as the integral over the scalar field:

$$A = \iint \mu(I(x,y), \tau) \, dx \, dy \qquad (17)$$

based on the membership function:

$$\mu(v, \tau) = \begin{cases} 1 & \text{if } v \geq \tau \\ 0 & \text{otherwise} \end{cases} \qquad (18)$$

**Table 15. ALGT_ISODENSITY Verification Conditions**

| Verification predicate | Prolog predicate/arity |
|---|---|
| $\forall C_j : d(C_j, M') < \epsilon$ | `ok_isodensity/6` |
| $\forall v \in C_j : d(v, M') < \epsilon$ | `ok_isodensity_pos/5` |
| $A(M') \approx A$ | `ok_isodensity_area/4` |

**Table 16. ALGT_ISODENSITY Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_ISODENSITY | |
| **Purpose:** Verifies the isodensity extraction algorithm | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Original CT scan in DICOM format. Threshold value. | |
| Algorithm Output Objects: Contour(s) from isodensity in DICOM format. | |
| **Test Steps:** | |
| Generate an ROI consisting of contour(s) on a single image plane, using the isodensity function with a specified threshold value. Export the single image and the structure set as DICOM file. Copy to 'temp' directory. Run 'ALGT_ISODENSITY' source. Specify CT image filename, structure set image file name, ROI number, and threshold value. Specify any testing parameters. | Test completes successfully. Statistics on test objects and test results are captured in log file. |

---

### 4.2.7 Beam SSD Calculation

**Table 17. ALGT_SSD Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1002 | General Mistreatment and/or Physical injury | Internal SSD calculation is incorrect (before dose calculation). | Code Review and Unit Test the SSD calculation |
| HZFS34 | | | The "Table" tab contains a text field that displays the SSD value for the selected beam. In non-SSD mode of planning, this text field is not editable. |

The source-surface distance for a beam with source position $s$ and direction $d$, with surface represented by mesh $M$, is the minimum of the set:

$$SSD = \min \{ \lambda : s + \lambda d \in M, \lambda > 0 \} \qquad (16)$$

A computed $SSD'$ is verified by direct comparison.

**Table 18. ALGT_SSD Verification Condition**

| Verification condition | Prolog predicate/arity |
|---|---|
| $\|SSD' - SSD\| < \epsilon$ | `ok_beam_ssd/4` |

**Table 19. ALGT_SSD Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_SSD | |
| **Purpose:** Verifies the source-skin distance algorithm | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Patient external mesh. Beam positions. | |
| Algorithm Output Objects: SSD value. | |
| **Test Steps:** | |
| Run 'ALGT_SSD' source. Specify Plan and Beam in Syngo database (LOID and Beam number). Test driver is executed to output contours and meshes. Test conditions are exercised on resulting objects. | Tests complete successfully. Test statistics and results are output to log file. |

---

### 4.2.8 Beam Volume Generation

**Table 20. ALGT_BEAM_VOLUME Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1034 | Mistreatment, dose to wrong location | The beam shape in the beams eye view does not correspond to the MLC shape as displayed | SW Design: display MPR view of intersection of beam shape wrt structures, as an independent means of visualizing the beam shape. |
| HZFS16 | | | The intersection of the beam with the MPR plane will be illustrated on the MPR image. Different methods may be used to display the beam of the MPR image. This will be controlled by the beam display properties. |

Given a beam with source at $s$ and shape $P$ as a point set on the isocentric plane, the beam volume is the set of all lines containing both $s$ and a point on $P$:

$$L_b = \{ l \in \mathcal{L}(\mathbb{R}^3) : s \in l \wedge \exists p \in P : p \in l \} \qquad (17)$$

$L_b$ is a line set — the corresponding point set is:

$$M_b = \{ v \in \mathbb{R}^3 : \exists l \in L_b : v \in l \} \qquad (18)$$

This defines an irregular conic projection converging on the beam source and extending indefinitely in both directions. In practice, the surface will be computed within a restricted region $H$ lying between the beam-limiting device plane and the imaging plane:

$$M_b' = M_b \cap H \qquad (19)$$

An algorithm that produces a suitable approximation $M_b'$ must satisfy two positional conditions. The first is that the beam's shape on the isocentric plane is contained within the surface:

$$P \subset M_b' \qquad (20)$$

The second positional condition is that the beam possesses the correct divergence. For a divergent surface consisting of planar structuring elements (such as facets), each structuring element must be coplanar with both the divergent source point $s$ and a line segment on the beam shape:

$$\forall f \in \mathcal{F}(M_b') : s \in \text{plane}(f) \wedge \exists e \in \mathcal{S}(P) : e \subset \text{plane}(f) \qquad (21)$$

The final condition is a volumetric condition. The expected volume of the surface is computed based on the area of the beam's shape at the isocentric plane, adjusted for the mesh divergence between the BLD plane and imaging plane:

$$V(M_b') \approx V_{expected}(A(P), SBLDD, SID) \qquad (22)$$

**Table 21. ALGT_BEAM_VOLUME Verification Conditions**

| Verification condition | Prolog predicate/arity |
|---|---|
| Combined | `ok_beam_volume/5` |
| $P \subset M_b'$ | `ok_beam_volume_shape/4` |
| $\forall f : s \in \text{plane}(f)$ | `ok_beam_volume_div/4` |
| $V(M_b') \approx V_{expected}$ | `ok_beam_volume_volume/4` |

**Table 22. ALGT_BEAM_VOLUME Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_BEAM_VOLUME | |
| **Purpose:** Verifies the beam volume generation algorithm | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Beam position, SAD, SBLDD, and SID. Beam shape as polygon(s) on isocentric plane, in text format. | |
| Algorithm Output Objects: Beam volume as VRML file. | |
| **Test Steps:** | |
| Run 'ALGT_BEAM_VOLUME' source. Specify Plan and Beam in Syngo database (LOID and Beam number). Test driver is executed to output beam parameters and meshes. Test conditions are exercised on resulting objects. | Tests complete successfully. Test statistics and results are output to log file. |

---

### 4.2.9 Beam Volume Planar Intersection

Intersection of the beam volume with an arbitrary plane is a special case of the mesh planar intersection in section 4.2.3. The same test procedure will be applied, using the beam volume as the mesh.

**Table 23. ALGT_BEAM_VOLUME_PLANAR Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1034 | Mistreatment, dose to wrong location | The beam shape in the beams eye view does not correspond to the MLC shape as displayed | SW Design: display MPR view of intersection of beam shape wrt structures, as an independent means of visualizing the beam shape. |
| HZFS16 | | | The intersection of the beam with the MPR plane will be illustrated on the MPR image. |

**Table 24. ALGT_BEAM_VOLUME_PLANAR Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_BEAM_VOLUME_PLANAR | |
| **Purpose:** Verifies the beam volume / plane intersection | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Mesh(es) representing beam volume in VRML format. Plane positions. | |
| Algorithm Output Objects: Polygons on planes. | |
| **Test Steps:** | |
| Run 'ALGT_BEAM_VOLUME_PLANAR' source. Specify Plan and Beam in Syngo database (LOID and Beam number). Specify offset and plane normal. Test driver is executed to output beam parameters and meshes. Test conditions are exercised on resulting objects. | Tests complete successfully. Test statistics and results are output to log file. |

---

### 4.2.10 Beam Central Axis / Isocenter Calculation

**Table 25. ALGT_BEAM_CAX_ISO Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1034 | Mistreatment, dose to wrong location | The beam shape in the beams eye view does not correspond to the MLC shape as displayed | SW Design: display MPR view of intersection of beam shape wrt structures, as an independent means of visualizing the beam shape. |
| HZFS16.1 | | | The beam intersection with the MPR plane shall include the beam's central axis projected onto the MPR plane, when the MPR plane is within the average slice thickness of the central axis and parallel to the central axis. |
| HZFS16.2 | | | The beam intersection with the MPR plane shall include the beam's isocenter projected onto the MPR plane as a cross-hair that is aligned with the beam's central axis, when the MPR plane is within the average slice thickness of the isocenter. |
| HZFS16.3 | | | The beam intersection shall include the intersection of the beam's central axis with the plane, when the central axis is not parallel to the plane. |

The beam central axis and isocenter calculations essentially transform three points from the IEC Beam coordinate system to the DICOM patient coordinate system. This is verified by direct comparison with the computed transform.

**Table 26. ALGT_BEAM_CAX_ISOCENTER Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_BEAM_CAX_ISOCENTER | |
| **Purpose:** Verifies the beam central axis and isocenter calculation | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Beam position, SBLDD, SAD, SID. | |
| Algorithm Output Objects: CAX Start and End positions, in DICOM patient coordinates. Isocenter, in DICOM patient coordinates. | |
| **Test Steps:** | |
| Run 'ALGT_BEAM_CAX_ISOCENTER' source. Specify Plan and Beam in Syngo database (LOID and Beam number). Test driver is executed to output beam parameters and meshes. Test conditions are exercised on resulting objects. | Tests complete successfully. Test statistics and results are output to log file. |

---

### 4.2.11 Structure Projection

**Table 27. ALGT_STRUCT_PROJ Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement |
|---|---|---|---|
| HZRA1029 | Mistreatment, dose to wrong location | The 3D structure produced from user drawn contours is not correct (e.g. wrong position, orientation, shape) due to an algorithm error. | SW Design: Display 3D structures w/DRR in the Beams Eye View (BEV) |
| HZFS53 | | | The upper right segment shows the BEV containing all the visible structures. |

The structure is projected for the BEV by applying the transformation from DICOM patient to Beam-perspective projection to each of the vertices in the mesh(s) representing the structure. This is verified by asserting that a set of projected coordinates is to within tolerance of the output coordinates.

**Table 28. ALGT_STRUCT_PROJ Test Procedure**

| Description | Expected Result |
|---|---|
| **Test Case Name:** ALGT_STRUCT_PROJ | |
| **Purpose:** Verifies the structure projection through a BEV | |
| **Precondition:** | |
| Algorithm Input Objects and Parameters: Beam position. Structure mesh, w/ vertices in DICOM patient coordinates. | |
| Algorithm Output Objects: Structure mesh, with vertices projected through beam projection. | |
| **Test Steps:** | |
| Run 'ALGT_STRUCT_PROJ' source. Specify StructureSet, ROI, Plan and Beam in Syngo database (LOIDs, ROI Number, and Beam number). Test driver is executed to output beam parameters and meshes. Test conditions are exercised on resulting objects. | Tests complete successfully. Test statistics and results are output to log file. |

---

### 4.2.12 DRR Calculation

> *Added in revision 4 (crutpr4.doc)*

**Table 29. ALGT_DRR Hazard Traceability**

| Hazard Key | Hazard | Cause | Requirement | IVT Risk Analysis Key(s) |
|---|---|---|---|---|
| HZRA1020 | Mistreatment, dose to wrong location | Incorrect computation of DRR due to incorrect masking of CT data (e.g. not according to the VOI selected by the user) | Code Review and Unit Test of DRR and SSDLP calculation with VOI and known data. | Svsbk_ivt_edit_position_information_SAFETY_sysek, Svsbk_ivt_coordsys_SAFETY_svsek |
| HZRA1021 | Mistreatment, dose to wrong location | The beam shape on the MPR image (including beam axis, and beam isocenter) is not correct | SW Design: display Beams Eye View (BEV) of beam shape, structures, and DRR as an independent means of visualizing the beam shape | (same) |
| HZRA1022 | Mistreatment, dose to wrong location | The Cross-Hair indicates the wrong position, relative to the true anatomy, in Virtual Fluoroscopy mode. | SW Design: Derive DRR parameters from the reference point position and the SAD | (same) |
| HZRA1028 | Mistreatment, dose to wrong location | The 3D structure produced from user drawn contours is not correct due to an algorithm error. | SW Design: Display 3D structures w/DRR in the Beams Eye View (BEV) | (same) |
| HZRA1033 | Mistreatment, dose to wrong location | DRR calculated with incorrect beam geometry due to algorithm error | Code Review and Unit Test the DRR and beam geometry calculations. | (same) |

The DRR calculation is performed by the Syngo IVT library. For this reason, these hazards are traced to the IVT Risk Analysis. The testing mitigations are traced to the IVT Hazard Test Specification, as per the above table.

---

## 5. Defects Handling

Any defects found during the execution of this test procedure will be raised as a CHARM, with build number based on the build of the test driver that output the data, and Found_in phase set to either IT (Integration Test) or ST (System Test), depending on the concurrent phase.

---

## 6. Test Results

Test results will be captured and output in the form of a report at the conclusion of testing. Test data will be captured and archived in ClearCase.

---

## 7. Appendices

### 7.1.1 Test Data

| Data Set | Object Name | Object Type | 4.2.1 Cont | 4.2.2 Mesh Gen | 4.2.3 Struct MPR | 4.2.4 2D Marg | 4.2.5 3D Marg | 4.2.6 Iso | 4.2.7 SSD | 4.2.8 Beam Vol | 4.2.9 Beam MPR | 4.2.10 Beam CAX | 4.2.11 Struct Proj |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| HFS Phantom | Cylinder | Geometric ROI | X | | | | | | | | | | |
| | Cube | Geometric ROI | X | X | | | | | | | | | |
| Lung Training | CTV | Convex ROI | X | X | X | | | | | | | | |
| | PTV | Convex ROI | X | X | X | X | | | | | | | |
| | L Lung | Non-convex ROI | X | X | X | X | | | | | | | |
| | Aorta | Bifurcated ROI | X | X | X | X | | | | | | | |
| | Patient | Large ROI | X | X | | | | | | | | | |
| | BeamAP | SSD Beam | | | | | | | X | X | X | | |
| | BeamBlk | Blocked beam | | | | | | | X | X | X | X | |
| | BeamMLC | MLC beam | | | | | | | X | X | X | X | |
| | BeamNCP | NCP Beam | | | | | | | X | X | X | X | X |
| LongVolumeScan | CTV | Non-convex ROI | X | X | | | | | | | | | |
| | Patient | Large ROI | X | X | | | | | | | | | |

### 7.1.2 Translation of Verification Conditions to Prolog Code

The following table maps the mathematical notation used in the verification conditions to their Prolog implementation:

| Mathematical Statement | Prolog Notation | Prolog Code |
|---|---|---|
| The statement X is implied by the statement Y ($X \leftarrow Y$) | `x :- y.` | `x :- y.` |
| Both the statement X and the statement Y are true ($X \wedge Y$) | `x, y` | `x, y` |
| Either the statement X or the statement Y are true ($X \vee Y$) | `x; y` | `x ; y` |
| For all elements of the set S, the statement Pr(x) is true ($\forall x \in S : Pr(x)$) | `forall(member(X, S), pr(X))` | `forall(member(X, S), pr(X))` |
| There exists at least one element of the set S, for which the statement Pr(x) is true ($\exists x \in S : Pr(x)$) | `member(X, S), pr(X), !` | `member(X, S), pr(X), !` |
| S is the set of all x such that the statement Pr(x) is true ($S = \{x : Pr(x)\}$) | `findall(X, pr(X), S)` | `findall(X, pr(X), S)` |

---

*Original source: `C:\Users\Derek\OneDrive\Timeline\62 Siemens\VSIM\VSIM_docs\Alg-CRUTPr\`*
*Converted from Microsoft Word (.doc) to Markdown: 2026-03-13*
*Equations reconstructed from context (original Equation Editor objects not extractable)*
