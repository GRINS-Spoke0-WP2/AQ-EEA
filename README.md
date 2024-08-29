# Air Quality data (AQ)

Air quality data are usually **observed** or **modeled**. **Observed** data represent the measurements made by operators and machines. They reflect the best approximation of the reality but they are prone to missingness, measurement errors, heterogeneity among measurements procedures, sparse availability, and other issues. **Modeled** data, on the other hand, generally show completeness and uniformity but they can significantly differ from the reality. Almost all mathematical models generating modeled data are divided in two different categories: **deterministic** and **stochastic**.

For the Italian domain, we retrieve AQ data from two different sources: the European Environmental Agency (**EEA**) and the Copernicus Atmosphere Monitoring Service (**CAMS**). **EEA** data are **observed** from the air quality monitoring stations and **CAMS** data are based on an ensemble of nine air quality data assimilation systems across Europe that use CTMs as based. Technical details about the sources are contained in the download sections [EEA 1: Download](#EEA-1-Download) and [CAMS 1: Download](#CAMS-1-Download), respectively. EEA data are available just at specific locations (the air quality monitoring network) while CAMS products are available on a full grid (cell centers lie on orthogonal straight lines) and cropped over the Italian domain. To use both the EEA and CAMS data simultaneously, data fusion techniques are required. 

## European Environmental Agency (EEA)

The following section contains the operations made on the EEA data:
1. [Download](#EEA-1-Download)
2. [Preprocess](#EEA-2-Preprocessing)
3. [Change of temporal resolution](#EEA-3-Change-of-temporal-resolution)

The following diagram summarises the process.

```mermaid
graph LR;
a[download]:::proc -->r[(csv raw files)]:::data
r --> b[preprocessing]:::proc
b --> i[(Rdata intermediate files)]:::data
i --> c[change temporal resolution]:::proc
c --> f[(EEA_dataset.Rdata)]:::data
classDef proc fill:#004E5A,color:#FFFFFF
classDef data fill:#E2FF59,color:#000000
```
The process makes extensive use of the functions contained in the [`functions.R`](script/AQ/EEA/functions.R) script.
