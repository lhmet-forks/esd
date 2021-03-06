# Documentation in subset.R
#' @export subset.station
subset.station <- function(x, it=NULL, is=NULL, loc=NULL, param=NULL,
                           stid=NULL, lon=NULL, lat=NULL, alt=NULL, cntr=NULL,
			   src=NULL, nmin=NULL, verbose=FALSE) {
    
    ##
    if (verbose) print('subset.station')
    if (is.null(attr(x,'unit'))) attr(x,'unit') <- NA
    if (verbose) print(c(varid(x),esd::unit(x)))
    d <- dim(x)
    if (inherits(it,c('field','station','zoo'))) {
        ## Match the times of another esd-data object
        if (verbose) print('field/station')
        x2 <- matchdate(x,it)
        return(x2)
    }
   
    if (inherits(is,c('field','station','zoo'))) {
        ## Match the times of another esd-data object
        if (verbose) print('is: field/station')
        x2 <- subset.station(x,is=loc(is))
        return(x2)
    }
    if (is.character(is)) {
      if (verbose) print('search on location names')
      ## search on location name
      locs <- tolower(loc(x))
      locs <- substr(locs,1,min(nchar(is)))
      is <- substr(is,1,min(nchar(is)))
      illoc <- is.element(locs,tolower(is))
      x2 <- subset(x,it=it,is=illoc,verbose=verbose)
      if (verbose) {print(is); print(loc(x2))}
      return(x2)
    }
    if (is.null(dim(x))) {
        x2 <- station.subset(x,it=it,is=1,verbose=verbose)
    } else {
        ##print("here")
        x2 <- station.subset(x,it=it,is=is,verbose=verbose)
        ## 
        ## extra selection based on meta data
        ## ss <- select.station(x=x2,loc = loc , param = param,  stid = stid ,lon = lon, lat = lat, alt = alt, cntr = cntr, src = src , nmin = nmin)
        ## 
        ## if (!is.null(ss)) {
        ##    id <- is.element(attr(x2,'station_id'),ss$station_id)
        ## Keep selected stations only
        ##    x2 <- station.subset(x2,it=it,is=which(id),verbose=verbose)
        ##}
        ##if (!is.null(is)) x2 <- station.subset(x2,it=it,is=is,verbose=verbose)
    }
    ## Check if there is only one series but if the dimension 
    if ( (!is.null(d)) & is.null(dim(x2)) ) 
      if (d[2]==1) dim(x2) <- c(length(x2),1)
    return(x2)
}

station.subset <- function(x,it=NULL,is=NULL,verbose=FALSE) {
  
  ## REB: Use select.station to condition the selection index is...
  ## loc - selection by names
  ## lon/lat selection be geography or closest if one coordinate lon/lat
  ##         if two-element vectors, define a region
  ## alt - positive values: any above; negative any below height
  ## cntr - selection by country
  ## 
  if (verbose) print("station.subset")
  if (verbose) print(c(varid(x),esd::unit(x)))
  nval <- function(x) sum(is.finite(x))
  x0 <- x
  if (is.null(it) & is.null(is)) return(x)
  
  ## Check whether matrix of vector
  d <- dim(x)
  if (is.null(d)) {
    if (verbose)
      print("Warning : One dimensional vector has been found in the coredata")
    x <- zoo(as.matrix(coredata(x)),order.by=index(x))
    x <- attrcp(x0,x)
    class(x) <- class(x0)
  } 
  d <- dim(x)
  
  if (is.null(is)) is <- 1:d[2]
  if (is.null(it)) it <- 1:d[1]
  if (is.logical(it)) it <- (1:d[1])[it]
  if (is.logical(is)) is <- (1:d[2])[is]
  
  ## get time in t
  t <- index(x)
  ii <- is.finite(t)
  
  if (verbose) print('it - temporal indexing')
  if (verbose) print(it)
  
  if (inherits(t,c("Date","yearmon"))) {
    if (verbose) print('years ++')
    yr <- year(x)
    mo <- month(x)
    dy <- day(x)
  } else if (inherits(t,c("numeric","integer"))) {
    if (verbose) print('years')
    yr <- t
    mo <- dy <- rep(1,length(t))
  } else print("Index of x should be a Date, yearmon, or numeric object")
  
  if(is.character(it)) {
    if ((levels(factor(nchar(it)))==10)) it <- as.Date(it)
  }
  
  if(inherits(it,c("POSIXt"))) it <- as.Date(it)
  
  if(inherits(it,c("Date"))) {
    if (inherits(t,"yearmon")) t <- as.Date(t)
    if ( length(it) == 2 ) {
      if (verbose) print('Between two dates')
      if (verbose) print(it)
      ii <- (t >= min(it)) & (t <= max(it))
    } else {
      ii <- is.element(t,it)
    }
  } else if(inherits(it,"yearmon")) {
    ii <- is.element(as.yearmon(t),it)
  } else if (is.character(it)) {
    if (verbose) print('it is character')
    if (sum(is.element(tolower(substr(it,1,3)),tolower(month.abb)))>0) {
      if (verbose) print('Monthly selected')
      if (is.seasonal(x)) {
        it <- gsub('Dec', 'Jan', it, ignore.case=TRUE)
        it <- gsub('Feb', 'Jan', it, ignore.case=TRUE)
        it <- gsub('Mar', 'Apr', it, ignore.case=TRUE)
        it <- gsub('May', 'Apr', it, ignore.case=TRUE)
        it <- gsub('Jun', 'Jul', it, ignore.case=TRUE)
        it <- gsub('Aug', 'Jul', it, ignore.case=TRUE)
        it <- gsub('Sep', 'Oct', it, ignore.case=TRUE)
        it <- gsub('Nov', 'Oct', it, ignore.case=TRUE)
      }
      ii <- is.element(month(x),(1:12)[is.element(tolower(month.abb),tolower(substr(it,1,3)))])
    } else if (sum(is.element(tolower(it),names(season.abb())))>0) {
      if (verbose) print("Seasonally selected")
      if (verbose) print(table(month(x)))
      if (verbose) print(eval(parse(text=paste('season.abb()$',it,sep=''))))
      ii <- is.element(month(x),eval(parse(text=paste('season.abb()$',it,sep=''))))
    }
  } else if (inherits(it,"Date")) {
    if (verbose) print('it is a Date object')
    ii <- is.element(t,it)
  } else if ((class(it)=="numeric") | (class(it)=="integer")) {
    if (verbose) print('it is numeric or integer')
    nlev <- as.numeric(levels(factor(nchar(it)))) # REB bug        
    # nchar returns the string length, but these lines need to find the number of different levels/categories
    # AM 2015-02-16 DO not agree    nlev <- as.numeric(levels(factor(as.character(it)))) # REB 2015-01-15
    if (verbose) {print(nlev); print(it)}
    if ((length(nlev)==1)) {
      if (nlev==4) {
        if (verbose) print("it are most probably years")
        if (length(it)==2) {
          ii <- is.element(yr,it[1]:it[2])
          if (verbose) print(paste('Subset of',sum(ii),'data points between',
                                   min(yr),'-',max(yr),'total:',length(yr)))
          # if it is years:
        } else if (min(it)> length(it)) {
          if (verbose) print("match years")
          ii <- is.element(yr,it)
        } 
      } else if (nlev<=4) {
        if (verbose) print("it are most probably seasons")
        if (inherits(x,'season') & (length(it)==1)) {
          if (verbose) print(paste("The 'it' value must be a season index between 1 and 4.",
                                   "If not please use character strings instead. e.g. it='djf'"))
          it <- switch(tolower(it),'1'=1,'2'=4,'3'=7,'4'=10,'djf'=1,'mam'=4,'jja'=7,'son'=10)
          ii <- is.element(mo,it)
        } else if ( (inherits(x,'month') | (inherits(x,'day'))) &
                    ( (max(it) <= 12) & (min(it) >= 1) ) ) {
          if (verbose) {
            print(paste("The 'it' value must be a month index.",
                        "If not please use character strings instead"))
            print(range(it))
          }
          ii <- is.element(mo,it)
        } else {
          if (verbose) print("it represents indices")
          ii <- it
        }
      } else if (nlev<=12  & ( (max(it) <= 12) & (min(it) >= 1) )) {
        if (verbose) {
          print(paste("The 'it' value are most probably a month index.",
                      "If not please use character strings instead"))
          print(range(it))
        }
        ii <- is.element(mo,it)
      } else {
        if (verbose) {
          print("The 'it' value are most probably an index.")
          print(range(it))
        }
        ii <- it
      }
    } else {
      #  length(nlev) > 1
      if (verbose) print("it most probably holds indices")
      ii <- it
    }
  } else {
    ii <- rep(FALSE,length(t))
    warning("subset.station: did not reckognise the selection citerion for 'it'")
  }
  
  class(x) -> cls
  ##print(cls)
  ## update the class of x
  class(x) <- "zoo"
  
  if (verbose) print('is - spatial indexing')
  
  ## REB 11.04.2014: is can be a list to select region or according to other criterion
  if (inherits(is,'list')) {
    if (verbose) print('is is a list object')
    n <- dim(x)[2]
    selx <- rep(TRUE,n); sely <- selx; selz <- selx
    selc <- selx; seli <- selx; selm <- selx; salt <- selx
    selp <- selx; selF <- selx ; sell <- selx
    nms <- names(is)
    il <- grep('loc',tolower(nms))
    ix <- grep('lon',tolower(nms))
    iy <- grep('lat',tolower(nms))
    #print(nms); print(c(ix,iy))
    iz <- grep('alt',tolower(nms))
    ic <- grep('cntr',tolower(nms))
    im <- grep('nmin',tolower(nms))
    ip <- grep('param',tolower(nms))
    id <- grep('stid',tolower(nms))
    iF <- grep('FUN',nms)
    if (length(il)>0) sloc <- is[[il]] else sloc <- NULL
    if (length(ix)>0) slon <- is[[ix]] else slon <- NULL
    if (length(iy)>0) slat <- is[[iy]] else slat <- NULL
    #print(slon); print(range(lon(x)))
    if (length(iz)>0) salt <- is[[iz]] else salt <- NULL
    if (length(ic)>0) scntr <- is[[ic]] else scntr <- NULL
    if (length(im)>0) snmin <- is[[im]] else snmin <- NULL
    if (length(ip)>0) sparam <- is[[ip]] else sparam <- NULL        
    if (length(id)>0) sstid <- is[[id]] else sstid <- NULL
    if (length(iF)>0) sFUN <- is[[iF]] else sFUN <- NULL
    #print(slat); print(range(lat(x)))
    if (length(sloc)>0) sell <- is.element(tolower(loc(x)),tolower(sloc))
    if (length(slon)==2) selx <- as.logical((lon(x) >= min(slon)) & (lon(x) <= max(slon)))
    if (length(slat)==2) sely <- as.logical((lat(x) >= min(slat)) & (lat(x) <= max(slat)))
    if (length(salt)==2) selz <- as.logical((alt(x) >= min(salt)) & (alt(x) <= max(salt)))
    if (length(salt)==1) {
      if (salt < 0) selz <- alt(x) <= abs(salt) else
        selz <- alt(x) >= salt
    }
    if (length(scntr)>0) selc <- is.element(tolower(cntr(x)),scntr)
    if (length(snmin)>0) selm <- apply(coredata(x),2,nval) > snmin
    if (length(sparam)>0) selp <- is.element(tolower(attr(x,"variable")),sparam)
    if (length(sstid)==2) seli <- (stid(x) >= min(sstid)) & (stid(x) <= max(sstid)) else
      if (length(sstid)>0) seli <- is.element(stid(x),sstid)
    if (length(sFUN)>0) selm <- apply(coredata(x),2,sFUN) # Not quite finished...
    ##
    is <- sell & selx & sely & selz & selc & seli & selm & selp & selF
    ##
    ## Need to make sure both it and is are same type: here integers for index rather than logical
    ## otherwise the subindexing results in an empty object
    if (verbose) print(paste(sum(is),'locations'))
  }
  
  if (verbose) print(paste('Subset of',sum(ii),'data points between',
                           min(yr),'-',max(yr),'total:',length(yr),
                           'from',length(is),'locations'))
  is[is.na(is)] <- FALSE
  if (is.logical(ii)) ii <- which(ii)
  if (is.logical(is)) is <- which(is)
  y <- x[ii,is]
  if (verbose) print(summary(coredata(y)))
  class(x) <- cls
  class(y) <- cls
  y <- attrcp(x,y,ignore=c("names"))
  attr(y,'location') <- loc(x)[is]
 
  if (length(esd::unit(x))== length(x[1,])) attr(y,'unit') <- esd::unit(x)[is] else
                                         attr(y,'unit') <- esd::unit(x)[1]
  if (length(varid(x))== length(x[1,])) attr(y,'variable') <- varid(x)[is] else
                                     attr(y,'variable') <- varid(x)[1]
  if (is.null(attr(y,'unit'))) attr(y,'unit') <- NA
  if (verbose) print(c(varid(x),esd::unit(x)))
  
  if (verbose) print(paste('Before subsetting',loc(x)[is],varid(x)[is],
                           esd::unit(x)[is],lon(x)[is],lat(x)[is]))
  if (verbose) print(is)
  
  attr(y,'longitude') <- attr(x,'longitude')[is]
  attr(y,'latitude') <- attr(x,'latitude')[is]
  
  if (!is.null(attr(y,'altitude')))
    attr(y,'altitude') <- attr(x,'altitude')[is]
  if (!is.null(attr(y,'country')))
    if (length(cntr(x))>1) attr(y,'country') <- cntr(x)[is] else
      attr(y,'country') <- cntr(x)
  if (!is.null(attr(y,'source')))
    if (length(src(x))>1) attr(y,'source') <- src(x)[is] else
      attr(y,'source') <- src(x)
  if (!is.null(attr(y,'station_id')))
    attr(y,'station_id') <- attr(x,'station_id')[is]
  if (!is.null(attr(y,'location')))
    attr(y,'location') <- attr(x,'location')[is]
  if (!is.null(attr(y,'quality')))
    attr(y,'quality') <- attr(x,'quality')[is]
  ## attr(y,'history') <- attr(x,'history')[is]
  # if (!is.null(attr(y,'variable')))
  #   if (length(varid(x))>1) attr(y,'variable') <- varid(x)[is] else
  #     attr(y,'variable') <- varid(x)
  ## attr(y,'element') <- attr(x,'element')[is]
  if (!is.null(attr(y,'aspect')))
    if (length(attr(y,'aspect'))>1) attr(y,'aspect') <- attr(x,'aspect')[is] else
      attr(y,'aspect') <- attr(x,'aspect')
  # if (!is.null(attr(y,'unit')))
  #   if (length(esd::unit(x))>1) attr(y,'unit') <- esd::unit(x)[is] else
  #     attr(y,'unit') <- esd::unit(x)
  if (!is.null(attr(y,'longname')))
    if (length(attr(y,'longname'))>1) attr(y,'longname') <- attr(x,'longname')[is] else
      attr(y,'longname') <- attr(x,'longname')
  if (!is.null(attr(y,'reference')))
    if (length(attr(y,'reference'))>1) attr(y,'reference') <- attr(x,'reference')[is] else
      attr(y,'reference') <- attr(x,'reference')
  if (!is.null(attr(y,'info')))
    if (length(attr(y,'info'))>1) attr(y,'info') <- attr(x,'info')[is] else
      attr(y,'info') <- attr(x,'info')
  if (!is.null(attr(y,'method')))
    if (length(attr(y,'method'))>1) attr(y,'method') <- attr(x,'method')[is] else
      attr(y,'method') <- attr(x,'method')
  if (!is.null(attr(y,'type')))
    if (length(attr(y,'type'))>1) attr(y,'type') <- attr(x,'type')[is] else
      attr(y,'type') <- attr(x,'type')
  if (!is.null(attr(y,'URL')))
    if (length(attr(y,'URL'))>1) attr(y,'URL') <- attr(x,'URL')[is] else
      attr(y,'URL') <- attr(x,'URL')
  if (!is.null(attr(y,'na')))
    if (length(attr(y,'na'))>1) attr(y,'na') <- attr(x,'na')[is] else
      attr(y,'na') <- attr(x,'na')
  
  if (verbose) print(paste('Final: ',loc(y),varid(y),esd::unit(y),lon(y),lat(y)))
  
  if (!is.null(err(y))) attr(y,'standard.error') <- err(x)[ii,is]
  ##attr(y,'date-stamp') <- date()
  ##attr(y,'call') <- match.call()
  attr(y,'history') <- history.stamp(x)
  if (inherits(y,"annual")) index(y) <- as.numeric(year(index(y)))
  return(y)
}
    
#' @export subset.stationmeta
subset.stationmeta <- function(x, it=NULL, is=NULL, verbose=FALSE) {
  if(verbose) print('subset.stationmeta')
  if (is.null(is)) is <- rep(TRUE,dim(x)[1])
  if (is.list(is)) {
    i <- rep(TRUE,length(x[[1]]))
    listnames <- names(is)
    if ('lon' %in% listnames) 
      i <- (lon(x) >= min(is$lon)) & (lon(x) <= max(is$lon)) 
    if ('lat' %in% listnames) 
      i <- i & (lat(x) >= min(is$lat)) & (lat(x) <= max(is$lat)) 
    if ('alt' %in% listnames) 
      i <- i & (alt(x) >= min(is$alt)) & (alt(x) <= max(is$alt))
    if ('cntr' %in% listnames) 
      i <- i & (is.element(tolower(substr(x$cntr,1,nchar(is$cntr))),tolower(is$cntr)))
    if ('param' %in% listnames) 
      i <- i & (is.element(tolower(substr(x$param,1,nchar(is$param))),tolower(is$param)))
    if ('src' %in% listnames) 
      i <- i & (is.element(tolower(substr(x$src,1,nchar(is$src))),tolower(is$src)))
    if ('loc' %in% listnames) 
      i <- i & (is.element(tolower(substr(x$location,1,nchar(is$loc))),tolower(is$loc)))
    is <- i
  } else if (is.numeric(is) | is.integer(is)) 
    is <- is.element(1:dim(x)[1],is) else if (is.character(is))
      is <- is.element(tolower(substr(x$location,1,nchar(is))),tolower(is))
    if (!is.null(it)) {
      is <- is & (x$start >= min(it)) & (x$end <= max(it))
    }
    if (verbose) print(paste('sub set of',sum(is),'elements'))
    is <- (1:dim(x)[1])[is]
    if (verbose) {print(dim(x)); print(is)}
    y <- x[is,]  
    if (verbose) print(dim(y))
    class(y) <- class(x)
    attr(y,'history') <- history.stamp(x)  
    if (verbose) str(y)
    return(y)
}
