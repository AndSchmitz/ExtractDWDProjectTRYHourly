# ExtractDWDProjectTRYHourly
This script extracts data at point locations from gridded hourly DWD "Project TRY" meteorological dataset.
 - [HTTPS link to data](https://opendata.dwd.de/climate_environment/CDC/grids_germany/hourly/Project_TRY/)
 - FTP link to data: ftp://opendata.dwd.de/climate_environment/CDC/grids_germany/hourly/Project_TRY/
 - [Dataset infopage](https://opendata.dwd.de/climate_environment/CDC/help/landing_pages/doi_landingpage_TRY_Basis_v001.html)
 - [Dataset reference](https://link.springer.com/article/10.1007%2Fs00704-016-2003-7)

## How to use
 - Download all files from this repository (e.g. via Code -> Download ZIP above).
 - Create a working directory and a subfolder "Input".
 - Copy the file "ExtractDWDProjectTRYHourly.R" into the working directory.
 - Copy the file "TargetLocations.csv" into the "Input" folder.
 - Install all libraries listed in the beginning of "ExtractDWDProjectTRYHourly.R"
 - Adjust the variable "WorkDir" in the beginning of "ExtractDWDProjectTRYHourly.R"
 - Download DWD Project TRY hourly data files (link see above). Store these files (.gz or .bz2 files) in the "Input" folder. Subfolders in the "Input" folder are also allowed, e.g. one subfolder per meteorological variable.
 - Run the "ExtractDWDProjectTRYHourly.R" script. Note that execution takes a while - start with a small number of input files (<5) first. Make sure you have at least 2 GB free space on hard disk (required for extraction of compressed .gz or .bz2 files).
 - Results will be stored in a subfolder named "Output" in the working directory.
 - Adjust "TargetLocations.csv" to the point locations you are interested in.

## Validation

The script has been valided by comparing output against values extracted with the linux tool [ncview](http://meteora.ucsd.edu/~pierce/ncview_home_page.html). The validation was done for the following 5 values (successful):

 - File: FF_199510.nc.gz Coordinate: 47.6501, 11.9478 Timestamp: 1995-10-01 03:00 Variable: FF Value: 12.2
 - File: FF_199510.nc.gz Coordinate: 54.4133, 13.3999 Timestamp: 1995-10-02 23:00 Variable: FF Value: 2.9
 - File: RH_201211.nc.gz Coordinate: 51.7592, 6.2417 Timestamp: 2012-11-03 01:00:00 Variable: humidity Value: 94.5
 - File: TT_199502.nc.bz2 Coordinate: 50.9358, 14.8578 Timestamp: 1995-02-01 02:00:00 Variable: temperature Value: 0.5
 - File: TT_199502.nc.bz2 Coordinate: 50.9532, 14.8891 Timestamp: 1995-02-01 22:00:00 Variable: temperature Value: 5.4

(data as of 2021-06-20). Please report any bugs / unexpected behaviour.
