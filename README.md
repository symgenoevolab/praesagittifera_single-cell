# praesagittifera_single-cell

This repository contains the code and resources associated with the following study:

Sakagami T, Kao LJ, Lewin TD, Chiu YL, Lin CT, Su JY, Wen SH, Wu MY, Arimoto A, Tagawa K, Bailly X, Lu TM, Luo YJ (2026). Convergent evolution of animal photosymbiosis through co-option of ancestral endodermal programs. bioRxiv 2026.10.22.760897. https://doi.org/10.64898/2026.10.22.760897

If you use any code or resources from this repository, please cite the above study.


---

The "main figure" directory includes:

- Pna_rsd_construction.Rmd [R script] (Figure 1c)

Generates a Seurat RDS object and UMAP plots from the single-cell RNA-seq dataset of _Praesagittifera naikaiensis_ deposited in NCBI GEO (GSE351334).



- Pna_DoHeatmap.Rmd [R script] (Figure 1d)

Generates a gene-expression heatmap with the top 10 marker genes for each cell type.



- Alge_region_segmentation.ijm [Fiji macro script] (Figure 2d)

Detects algal autofluorescence in confocal images and measures algal area within host worms to calculate algal density.


- TEM_starch_measure.ijm [Fiji macro script] (Figure 2f)

Detects starch granules in algal symbionts in TEM images and measures their area to calculate starch density.


---
Resources: 

Single-cell RNA sequencing data are available through NCBI Gene Expression Omnibus (GEO) under accession GSE351334.

Gene models, including coding sequences, protein sequences and gene annotations, and gene lists used in this study are deposited in Zenodo (https://doi.org/10.5281/zenodo.23496335)
