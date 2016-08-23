## Interferometric SAR processing of Sentinel 1 images with SNAP

#### Overview

This repository contains the application files and scripts to process a pair (Master and Slave) of Sentinel 1 TOPSAR IW data with [SNAP](http://step.esa.int/main/toolboxes/snap) (SeNtinel’s Application Platform), which is the common architecture for all Sentinel Toolboxes jointly developed by Brockmann Consult, Array Systems Computing and C-S.
The interferometric processing chain for Sentinel 1 TOPSAR IW images is implemented through the tools contained in the [Sentinel-1 Toolbox](http://step.esa.int/main/toolboxes/sentinel-1-toolbox).

#### The interferometric SAR technique  

Interferometric synthetic aperture radar (InSAR) exploits the phase difference between two complex radar SAR observations taken from slightly different sensor positions and extracts information about the earth’s surface. A SAR signal contains amplitude and phase information. The amplitude is the strength of the radar response and the phase is the fraction of one complete sine wave cycle (a single SAR wavelength). The phase of the SAR image is determined primarily by the distance between the satellite antenna and the ground targets. By combining the phase of these two images after coregistration, an interferogram can be generated whose phase is highly correlated to the terrain topography.
The InSAR technique can potentially measure millimetre-scale changes in deformation over spans of days to years. It has applications for geophysical monitoring of natural hazards, for example earthquakes, volcanoes and landslides, and in structural engineering, in particular monitoring of subsidence and structural stability.

#### Sentinel-1 Interferometric Wide Swath Products

The Interferometric Wide (IW) swath mode is the main acquisition mode over land for Sentinel-1. It acquires data with a 250 km swath at 5 m by 20 m spatial resolution (single look). IW mode captures three sub-swaths using Terrain Observation with Progressive Scans SAR (TOPSAR). With the TOPSAR technique, in addition to steering the beam in range as in ScanSAR, the beam is also electronically steered from backward to forward in the azimuth direction for each burst, avoiding scalloping and resulting in homogeneous image quality throughout the swath. 
TOPSAR mode replaces the conventional ScanSAR mode, achieving the same coverage and resolution as ScanSAR, but with a nearly uniform SNR (Signal-to-Noise Ratio) and DTAR (Distributed Target Ambiguity Ratio). IW SLC products contain one image per sub-swath and one per polarisation channel, for a total of three (single polarisation) or six (dual polarisation) images in an IW product.
Each sub-swath image consists of a series of bursts, where each burst has been processed as a separate SLC image. The individually focused complex burst images are included, in azimuth time order, into a single sub-swath image with black-fill demarcation in between, similar to ENVISAT ASAR Wide ScanSAR SLC products.


## Quick link

* [Getting Started](#getting-started)
* [Installation](#installation)
* [Submitting the workflow](#submit)
* [Community and Documentation](#community)
* [Authors](#authors)
* [Questions, bugs, and suggestions](#questions)
* [License](#license)

### <a name="getting-started"></a>Getting Started

To run this application you will need a Developer Cloud Sandbox, that can be either requested from:
* ESA [Geohazards Exploitation Platform](https://geohazards-tep.eo.esa.int) for GEP early adopters;
* ESA [Research & Service Support Portal](http://eogrid.esrin.esa.int/cloudtoolbox/) for ESA G-POD related projects and ESA registered user accounts
* From [Terradue's Portal](http://www.terradue.com/partners), provided user registration approval.

A Developer Cloud Sandbox provides Earth Sciences data access services, and helper tools for a user to implement, test and validate a scalable data processing application. It offers a dedicated virtual machine and a Cloud Computing environment.
The virtual machine runs in two different lifecycle modes: Sandbox mode and Cluster mode.
Used in Sandbox mode (single virtual machine), it supports cluster simulation and user assistance functions in building the distributed application.
Used in Cluster mode (a set of master and slave nodes), it supports the deployment and execution of the application with the power of distributed computing for data processing over large datasets (leveraging the Hadoop Streaming MapReduce technology).

### <a name="installation"></a>Installation

#### Dependencies 

SNAP will be automatically installed together with this application installation. 

> SNAP is licensed under [GNU GPL v3](https://www.gnu.org/licenses/gpl.html). For more information about SNAP go to [SNAP](http://step.esa.int/main/toolboxes/snap).

##### Using the releases

Log on the developer cloud sandbox. Download the RPM package from https://github.com/geohazards-tep/dcs-rss-snap-s1-insar/releases.
Install the downloaded package by running these commands in a shell:

```bash
sudo yum -y install rss-snap-s1-insar-<version>.noarch.rpm
```

#### Using the development version

Log on the developer sandbox and run these commands in a shell:

```bash
cd
git clone https://github.com/geohazards-tep/dcs-rss-snap-s1-insar.git
cd rss-snap-s1-insar
mvn install
```

### <a name="submit"></a>Submitting the workflow

Run this command in a shell:

```bash
ciop-run
```
Or invoke the Web Processing Service via the Sandbox dashboard or the [Geohazards Thematic Exploitation platform](https://geohazards-tep.eo.esa.int) providing the following items:

#### Master and Slave products' reference:

These are the URLs of the master and slave products to be processed, for example:
* https://data2.terradue.com/eop/scihub/dataset/search?uid=S1A_IW_SLC__1SDV_20160123T051846_20160123T051914_009617_00E01B_3EC0 (default master)
* https://data2.terradue.com/eop/scihub/dataset/search?uid=S1A_IW_SLC__1SDV_20160216T051846_20160216T051914_009967_00EA4B_E31C (default slave)

#### Product subswath

Define the subswath(s) to be processed:
* IW1 (default)
* IW2
* IW3
* IW1,IW2
* IW2,IW3
* IW1,IW2,IW3

#### Product polarisation

Define the polarization to be processed. Note that such polarization must be contained in the master-slave couple. For example VV is not present in "DH" or "SH" products. 
The following values can be chosen:
* VV (default)
* VH
* HH
* HV

#### Orbit type
                        
Define the orbit source for the Orbit Correction:
* Sentinel Precise
* Sentinel Restituted (default) 

#### Azimuth coherence window size

Define the coherence estimation azimuth window size for the Interferogram processing [integer number of pixels]: 6 is used as default.

#### Range coherence window size

Define the coherence estimation range window size for the Interferogram processing [integer number of pixels]: 20 is used as default.          

#### Multilook factor

Define the multilook factor applied for both Azimuth and Range directions in the Multilooking processing [integer]: 2 is used as default.

#### Pixel spacing in meters

Define the pixel spacing for the Terrain-Correction processing [meters]: 15.0 is used as default.

To learn more and find information go to

* [Developer Cloud Sandbox](http://docs.terradue.com/developer) service
* [SNAP](http://step.esa.int/main/toolboxes/snap)
* [Sentinel-1 Toolbox](http://step.esa.int/main/toolboxes/sentinel-1-toolbox)
* [Sentinel-1 TOPSAR Interferometry Tutorial with S1TBX](http://sentinel1.s3.amazonaws.com/docs/S1TBX%20TOPSAR%20Interferometry%20with%20Sentinel-1%20Tutorial.pdf) 
* [ESA Geohazards Exploitation Platform](https://geohazards-tep.eo.esa.int)

### <a name="authors"></a>Authors (alphabetically)

* RSS Team

### <a name="questions"></a>Questions, bugs, and suggestions

Please file any bugs or questions as [issues](https://github.com/geohazards-tep/dcs-rss-snap-s1-insar/issues) or send in a pull request.

### <a name="license"></a>License

This application is licensed under the [GNU GPL v3](https://www.gnu.org/licenses/gpl.html).
