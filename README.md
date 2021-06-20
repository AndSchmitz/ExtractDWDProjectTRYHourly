# ExtractDWDProjectTRYHourly
This script extract data at point locations from gridded hourly DWD "Project TRY" meteorological dataset.
 - [HTTPS link to data](https://opendata.dwd.de/climate_environment/CDC/grids_germany/hourly/Project_TRY/)
 - FTP link to data: ftp://opendata.dwd.de/climate_environment/CDC/grids_germany/hourly/Project_TRY/

How to use:
 - Download all files from this repository (e.g. via Code -> Download ZIP above).
 - Create a working directory and a subfolder "Input".
 - Copy the file "ExtractDWDProjectTRYHourly.R" into the working directory.
 - Copy the file "TargetLocations.csv" into the "Input" folder.
 - Install all libraries listed in the beginning of "ExtractDWDProjectTRYHourly.R"
 - Adjust the variable "WorkDir" in the beginning of "ExtractDWDProjectTRYHourly.R"
 - Download DWD Project TRY hourly data files (link see above). Store these files (.gz or .bz2 files) in the "Input" folder. Subfolders in the "Input" folder are also allowed, e.g. one subfolder per meteorological variable.
 - Run the "ExtractDWDProjectTRYHourly.R" script. Note that execution takes a while - start with a small number of input files (<5) first.
 - Results will be stored in a subfolder named "Output" in the working directory.
