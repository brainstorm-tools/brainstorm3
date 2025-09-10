---
title: 'sEEG-Suite: An Interactive Pipeline for Semi-Automated Contact Localization and Anatomical Labeling with Brainstorm'
tags:
  - sEEG
  - Brainstorm
  - contact localization
  - electrode labeling
  - epilepsy
  - co-registration
  - neuroimaging
authors:
  - name: Adrian M. Price-Whelan
    orcid: 0000-0000-0000-0000
    equal-contrib: true
    affiliation: "1, 2" # (Multiple affiliations must be quoted)
  - name: Author Without ORCID
    equal-contrib: true # (This is how you can denote equal contributions between multiple authors)
    affiliation: 2
  - name: Author with no affiliation
    corresponding: true # (This is how to denote the corresponding author)
    affiliation: 3
  - given-names: Ludwig
    dropping-particle: van
    surname: Beethoven
    affiliation: 3
affiliations:
 - name: Lyman Spitzer, Jr. Fellow, Princeton University, United States
   index: 1
   ror: 00hx57361
 - name: Institution Name, Country
   index: 2
 - name: Independent Researcher, Country
   index: 3

authors:
  - name: Chinmay Chinara
    orcid: 0000-0002-4474-1359
    equal-contrib: true
    corresponding: true
    affiliation: 1
  - name: Raymundo Cassani
    equal-contrib: true
    corresponding: true
    affiliation: 2
  - name: Takfarinas Medani
    corresponding: true
    affiliation: 1
  - name: Anand A. Joshi
    affiliation: 1
  - name: Samuel M. Villalon
    affiliation: 3
  - name: Yash S. Vakilna
    affiliation: "4, 6"
  - name: Johnson Hampson
    affiliation: 4
  - name: Kenneth Taylor
    affiliation: 5
  - name: Francois Tadel
    affiliation: 7
  - name: Dileep Nair
    affiliation: 5
  - name: Christian G. Bénar
    affiliation: 3
  - name: Sylvain Baillet
    affiliation: 2
  - name: John Mosher
    affiliation: 4
  - name: Richard M. Leahy
    affiliation: 1
affiliations:
 - name: University of Southern California, USA
   index: 1
 - name: McGill University, Canada
   index: 2
 - name: Institut de Neurosciences des Systèmes, France
   index: 3
 - name: University of Texas Health Science Center at Houston, USA
   index: 4
 - name: Cleveland Clinic, USA
   index: 5
 - name: Rice University, USA
   index: 6
 - name: Independent Research Engineer, France
   index: 7
date: 10 September 2025
bibliography: paper.bib
---

# Summary

Stereoelectroencephalography (sEEG) is a critical tool for mapping epileptic networks in patients with drug-resistant epilepsy. Accurate localization and labeling of sEEG contacts are essential for identifying the seizure onset zone (SOZ) and ensuring optimal resective surgery. Traditional methods for localizing and labeling sEEG contacts rely on manual processing, which is prone to human error and variability. To address these challenges, we developed and integrated a semi-automatic sEEG contact localization and labeling pipeline within Brainstorm[@Tadel:2011], an open-source software platform for multimodal brain imaging analysis[@Tadel:2019; @Niso:2019; @Nasiotis:2019; @da-Silva-Castanheira:2021; @Medani:2023; @Delaire:2025; @Vakilna:2025], widely adopted in the neuroscience community with over 50,000 registered users with an active online [user forum](https://neuroimage.usc.edu/forums/). The software has been [supported](https://neuroimage.usc.edu/brainstorm/Introduction#Support) by the National Institute of Health (NIH) for over two decades. The pipeline presented in this paper performs: (1) import and apply rigid co-registration of post-implantation Computed Tomography (CT) or post-CT with pre-implantation Magnetic Resonance Imaging (pre-MRI), (2) post-CT image segmentation and semi-automatic detection of sEEG contacts using GARDEL[@Medina-Villalon:2018], which has been integrated as a [Brainstorm plugin](https://neuroimage.usc.edu/brainstorm/Tutorials/Plugins), and (3) automatic anatomical labeling of contacts using standard and commonly used [brain anatomy templates and atlases](https://neuroimage.usc.edu/brainstorm/Tutorials/DefaultAnatomy). Integrating this pipeline into Brainstorm brings the best of both worlds: GARDEL's automation and Brainstorm’s user-friendly interface, multimodal data compatibility, and rich library of visualization and advanced analysis tools for the sEEG data, both at the sensor and source level[@Vakilna:2025]. This sEEG-Suite tool facilitates reproducible research, supports clinical workflows, and accelerates sEEG-based investigations of invasive brain recordings.

# Statement of need

Intracranial electrode localization, particularly for sEEG, is a foundational step in epilepsy surgery planning and neuroscience research. At present, many researchers and clinicians rely on manual workflows or a patchwork of separate tools for localization, which results in time-consuming procedures, inter-operator variability, and fragmented pipelines. Manual identification and labeling of electrode contacts can take several hours per subject, slowing down the workflows, while subjective differences between operators introduce inconsistencies in results. Moreover, existing practices often require multiple platforms, i.e., one for CT-MRI co-registration, another for electrode detection, and another for anatomical labeling, and another for data analysis, thereby adding unnecessary complexity and risk of errors in the final results.

Integrating GARDEL with Brainstorm provides seamless, one-click deployment of intracranial electrode localization directly within Brainstorm, eliminating the need for external scripts and reducing  manual intervention. This reduces localization time from hours to minutes (with some minor post-processing), enabling researchers to efficiently scale analyses across larger patient cohorts. The integration also enhances reproducibility by standardizing detection parameters, minimizing manual intervention, and unifying the entire workflow of co-registration, localization, visualization, and atlas-based labeling into a single interactive environment.

While other tools, such as DEETO[@Arnulfo:2015], 3D Slicer’s sEEG Assistant[Narizzano:2017], FASCILE[@Ervin:2021] and LeGUI[@Davis:2021] have demonstrated dramatic speedups compared to manual localization, they do not provide an end-to-end processing workflow from anatomical to functional analyses like Brainstorm that does.

# Acknowledgements

Research reported in this publication was supported by the National Institute of Biomedical Imaging and Bioengineering (NIBIB) of the National Institutes of Health (NIH) under award numbers R01EB026299 and RF1NS133972.

# References
