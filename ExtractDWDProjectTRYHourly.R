#Extract hourly grid data from DWD Project TRY
#https://opendata.dwd.de/climate_environment/CDC/help/landing_pages/doi_landingpage_TRY_Basis_v001.html
#This script only extracts data. It does not change variable names, units of values
#or date-time formats (date-time is treated as a string in this script).
#It does, however, round values to save memory (precision can be changed below).
#
#For importing the resulting data in later processing steps, the TimeStamp column of the output
#can be imported with correct timezone settings like this:
# Output <- Output %>%
#   mutate(
#     TimeStamp = as.POSIXct(
#       x = paste0(TimeStamp,"0000"),
#       tz = "UTC+1",
#       format = "%Y%m%d%H%M%S"
#     )
#as time is assumed to be provided in UTC+1=GMT+1 by DWD
#(no indication of daylight saving time usage found in data).

    
#init-----
rm(list=ls())
graphics.off()
options(
  warnPartialMatchDollar = T,
  stringsAsFactors = F
)
library(tidyverse) #for data handling
library(R.utils) #for unzipping bz2 and gz files
library(ncdf4) #for NetCDF handling
library(rgdal) #for projection of coordinates
library(LaF) #for working with very large files
library(geosphere) #for calculating spatial distances

#Set working directory
WorkDir <- "/path/to/your/WorkDir"


#  --- No changes required below this line ---

#Prepare I/O
InDir <- file.path(WorkDir,"Input")
OutDir <- file.path(WorkDir,"Output")
dir.create(OutDir,showWarnings = F)
OutputFile <- file.path(OutDir,"HourlyDWDDataExctracted.csv")
CoordsFileName <- "TargetLocations.csv"

#Define the number of decimal places for for the extracted values
#(NetCDF files provide values with lots of decimal places)
ValueDecimalPrecision <- 2

#The variables containing the actual values (rel. humid, wind speed, etc.)
#are always the fiths variable in the NC files.
VarPositionNetCDFFile <- 5


#Prepare coords for points to extract----
StartTime <- Sys.time()
PointCoords <- read.table(
  file = file.path(InDir,CoordsFileName),
  header = T,
  sep = ";",
  dec = ".",
  stringsAsFactors = F
) %>%
  select(LocationLabel,Lat_EPSG4326,Lon_EPSG4326) %>%
  mutate(
    LocationLabel = as.character(LocationLabel)
  )
if ( any( is.na(PointCoords) ) ) {
  stop("File with coordinates must not contain NA.")
}
nPointCoords <- nrow(PointCoords)


#List all data files-----
#Some files come as BZ2 others as GZ
InputFiles <- list.files(
  path = InDir,
  pattern = ".bz2|.gz",
  recursive = T,
  full.names = T
)


#Helper functions to unzip BZ2 and GZ files-----
UnzipFile <- function(SourceFilePath, TargetFilePath) {

  if ( grepl(x = SourceFilePath, pattern = ".bz2") ) {
  
    bunzip2(
      filename = SourceFilePath,
      destname = TargetFilePath,
      overwrite = T,
      remove = F
    )
    
  } else if ( grepl(x = SourceFilePath, pattern = ".gz") ) {
    
    gunzip(
      filename = SourceFilePath,
      destname = TargetFilePath,
      overwrite = T,
      remove = F
    )
    
  } else {
    stop(paste("Dont know how to extract file",SourceFilePath))
  }

  return()
}


#Identify grid cells for desired coords---------------------------
print("Identifying DWD data grid cells matching point locations specified in TargetLocations.csv...")
#Load the first NetCDF file and for each desired output location
#in PointCoords identify the corresponding grid cell where to extract
#data. This mapping is then used for all input files.
CurrentFile_NC <- file.path(OutDir,"CurrentFile.nc")
UnzipFile(
  SourceFilePath = InputFiles[1],
  TargetFilePath = CurrentFile_NC
)
NetCDFFileHandle <- nc_open(CurrentFile_NC)

#Convert coords from ETRS89 / ETRS-LCC, Ellipsoid GRS80, EPSG: 3034
#http://spatialreference.org/ref/epsg/3034/
#to standard WGS84 EPSG4326
#Extract dimensions X and Y for the grid of values fron first data file in list
Lon_EPSG3034_File1 <- as.numeric(NetCDFFileHandle$var[[VarPositionNetCDFFile]]$dim[[1]]$vals)
Lat_EPSG3034_File1 <- as.numeric(NetCDFFileHandle$var[[VarPositionNetCDFFile]]$dim[[2]]$vals)
nc_close(NetCDFFileHandle)
#Create all combinations of X and Y coords
AllCoords <- as.data.frame(expand.grid(
  Lon_EPSG3034_File1 = Lon_EPSG3034_File1,
  Lat_EPSG3034_File1 = Lat_EPSG3034_File1
))
#Convert to a spatial object
coordinates(AllCoords) <- c("Lon_EPSG3034_File1", "Lat_EPSG3034_File1")
suppressWarnings(proj4string(AllCoords) <- CRS("+init=epsg:3034"))
#Convert projection to EPSG4326
CRS.new <- CRS("+init=epsg:4326") #WGS84 standard coordinates
AllCoordsEPSG4326 <- spTransform(AllCoords, CRS.new) %>%
  as.data.frame(AllCoordsWGS84) %>%
  rename(
    Lon_EPSG4326_File1 = Lon_EPSG3034_File1,
    Lat_EPSG4326_File1 = Lat_EPSG3034_File1
  )
AllCoords <- bind_cols(
  as.data.frame(AllCoords),
  AllCoordsEPSG4326
)
#For each desired location in PointCoords, identify the corresponding grid cell
PointCoords <- PointCoords %>%
  mutate(
    DWDGridCellLonEPSG3034 = NA,
    DWDGridCellLatEPSG3034 = NA,
    DWDArrayIndex_X = NA,
    DWDArrayIndex_Y = NA
  )
for ( i in 1:nPointCoords ) {
  #For each point in PointCoords, find the grid cell which has the smallest distance
  #from its coordinates to the point.
  #Old calculation without using correct spatial distances
  #DistVec <- sqrt( (AllCoords$Lon_EPSG4326_File1 - CurrentLon)^2 + (AllCoords$Lat_EPSG4326_File1 - CurrentLat)^2 )
  #New calculation with geosphere::distm()
  DistVec <- as.vector(geosphere::distm(
    x = as.matrix(PointCoords[i,c("Lon_EPSG4326","Lat_EPSG4326")]),
    y = as.matrix(AllCoords[,c("Lon_EPSG4326_File1","Lat_EPSG4326_File1")]),
    fun = distHaversine
  )) / 1000 #Distance in km
  
  idx_MinDist <-which( DistVec == min(DistVec) )
  if ( length(idx_MinDist) != 1 ) {
    CurrentLon <- PointCoords$Lon_EPSG4326[i]
    CurrentLat <- PointCoords$Lat_EPSG4326[i]
    CurrentLabel <- PointCoords$LocationLabel[i]
    stop(paste("Could not find a single unique DWD grid cell for point labelled",CurrentLabel,"with coords",CurrentLat,CurrentLon))
  }
  PointCoords$DWDGridCellLonEPSG3034[i] <- AllCoords$Lon_EPSG3034_File1[idx_MinDist]
  PointCoords$DWDGridCellLatEPSG3034[i] <- AllCoords$Lat_EPSG3034_File1[idx_MinDist]
  PointCoords$DWDArrayIndex_X[i] <- which(Lon_EPSG3034_File1 == PointCoords$DWDGridCellLonEPSG3034[i])
  PointCoords$DWDArrayIndex_Y[i] <- which(Lat_EPSG3034_File1 == PointCoords$DWDGridCellLatEPSG3034[i])
}
file.remove(CurrentFile_NC)


#Extract data, loop over input files------
for ( iCurrentFile in 1:length(InputFiles) ) {
  print(paste("Extracting data from file",iCurrentFile, "of",length(InputFiles),"..."))
  
  #_Unzip------
  #Unzip current compressed nc file
  CurrentInputFile <- InputFiles[iCurrentFile]
  CurrentFile_NC <- file.path(OutDir,"CurrentFile.nc")
  UnzipFile(
    SourceFilePath = CurrentInputFile,
    TargetFilePath = CurrentFile_NC
  )
  NetCDFFileHandle <- nc_open(CurrentFile_NC)
  
  #_Check coords-----
  #Check list of X and Y coords against first file.
  #The coords must not change between files.
  Lon_EPSG3034_CurrentFile <- as.numeric(NetCDFFileHandle$var[[VarPositionNetCDFFile]]$dim[[1]]$vals)
  Lat_EPSG3034_CurrentFile <- as.numeric(NetCDFFileHandle$var[[VarPositionNetCDFFile]]$dim[[2]]$vals)
  if (
    (length(Lon_EPSG3034_CurrentFile) != length(Lon_EPSG3034_File1) ) ||
    (length(Lat_EPSG3034_CurrentFile) != length(Lat_EPSG3034_File1) ) ||
    (any(Lat_EPSG3034_CurrentFile != Lat_EPSG3034_File1)) ||
    (any(Lon_EPSG3034_CurrentFile != Lon_EPSG3034_File1))
  ) {
    stop(paste("Lat and/or lon coordinates differ between file",
               basename(InputFiles[1]), "and file",
               basename(CurrentFile_NC)
    ))
  }
  
  #_Get name of current variable-----
  CurrentVariable <- names(NetCDFFileHandle$var)[VarPositionNetCDFFile]
  
  #_Get date and time----
  #Sometimes NCDF variable is called "datum", sometimes "Datum"
  if ( "datum" %in% names(NetCDFFileHandle$var) ) {
    DateVarName = "datum"
  } else if ( "Datum" %in% names(NetCDFFileHandle$var) ) {
    DateVarName = "Datum"
  } else {
    stop("Neither \"datum\" nor \"Datum\" are valid variable names in current NetCDF file.")
  }
  TimeStamps <- as.character(ncvar_get(
    nc = NetCDFFileHandle,
    varid = DateVarName
  ))

  
  #_Loop over locations-----
  OutputCurrentFile <- list()
  for ( iPointCoord in 1:nPointCoords ) {
    
    LocationLabel <- PointCoords$LocationLabel[iPointCoord]
    DWDArrayIndex_X <- PointCoords$DWDArrayIndex_X[iPointCoord]
    DWDArrayIndex_Y <- PointCoords$DWDArrayIndex_Y[iPointCoord]
  
    #Get values for current grid cell for all dates
    Value <- ncvar_get(
      nc = NetCDFFileHandle,
      varid = CurrentVariable,
      #Dimenions: lon, lat, hour
      start = c(DWDArrayIndex_X,DWDArrayIndex_Y,1),
      count = c(1,1,-1),
      verbose = F,
      raw_datavals = F
    )
    
    #Insert data into dataframe for current file's results
    tmp <- data.frame(
      LocationLabel = LocationLabel,
      TimeStamp = TimeStamps,
      Variable = CurrentVariable,
      Value = Value
    )
    OutputCurrentFile[[length(OutputCurrentFile)+1]] <- tmp
    
  } #end of loop over locations
  
  #_Write results for current input file-----
  #Convert the output list to a data frame and round value
  OutputCurrentFileDF <- bind_rows(OutputCurrentFile) %>%
    mutate(
      Variable = as.character(Variable),
      Value = round(Value,ValueDecimalPrecision)
    )
  write.table(
    x = OutputCurrentFileDF,
    file = OutputFile,
    sep = ";",
    row.names = F,
    #Write header row only for the first file.
    #Else, just append the data.
    append = ifelse(
      test = (iCurrentFile == 1),
      yes = F,
      no = T
    ),
    col.names = ifelse(
      test = (iCurrentFile == 1),
      yes = T,
      no = F
    )
  )
    
  #_Cleanup-----
  #Close and delete current extracted file
  nc_close(NetCDFFileHandle)
  file.remove(CurrentFile_NC)
    
} #end of loop over input files


#Split output into one file per LocationLabel----
print("Splitting data into one file per LocationLabel...")
#To avoid memory problems with (potentially very large) file "OutputFile".
#Create directory for single files per location
SinglesFilePerLocationLabelDir <- file.path(OutDir,"SinglesFilePerLocationLabel")
dir.create(
  path = SinglesFilePerLocationLabelDir,
  showWarnings = F
)
#Open (potentially very large) file "OutputFile". 
#Use R package LaF to avoid memory problems with large files.
DataModelForReadingLargeFile <- detect_dm_csv(
  filename = OutputFile,
  sep=";",
  header=TRUE,
  stringsAsFactors = F
)
DataModelForReadingLargeFile$columns$type[DataModelForReadingLargeFile$columns$name == "LocationLabel"] <- "string"
DataModelForReadingLargeFile$columns$type[DataModelForReadingLargeFile$columns$name == "TimeStamp"] <- "string"
DataModelForReadingLargeFile$columns$type[DataModelForReadingLargeFile$columns$name == "Variable"] <- "string"
DataModelForReadingLargeFile$columns$type[DataModelForReadingLargeFile$columns$name == "Value"] <- "double"
AllData <- laf_open(
  model = DataModelForReadingLargeFile
)
#Extract data for each location and write to separate file
if ( nrow(AllData) == 0 ) {
  stop("Error: OutputFile seems to be empty.")
}
for ( CurrentLocationLabel in unique(AllData$LocationLabel[]) ) {
  #Use LaF library-style indexing [] to filer for current location
  Sub <- AllData[AllData$LocationLabel[] == CurrentLocationLabel,]
  #Save data for current location as csv
  write.table(
    x = Sub,
    file = file.path(SinglesFilePerLocationLabelDir,paste0(CurrentLocationLabel,".csv")),
    sep = ";",
    row.names = F
  )
  rm(Sub)
}


#Finish----
EndTime <- Sys.time()
TimeElapsed <- difftime(
  time1 = EndTime,
  time2 = StartTime,
  units = "hours"
)
TimeElapsed <- round(as.numeric(TimeElapsed),2)
AverageDurationPerFile = round(TimeElapsed / length(InputFiles),2)
  
print(paste("Start time:",StartTime))
print(paste("End time:",EndTime))
print(paste("Time elapsed:",TimeElapsed,"hours"))
print(paste("Average duration per file:",AverageDurationPerFile,"hours"))
print(paste("Number of files processed:",length(InputFiles)))
      
