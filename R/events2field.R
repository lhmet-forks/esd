#' Transform an input object into a \code{field} object  
#' 
#' Transform a \code{trajectory} object into a \code{field} object by aggregating it in time and space.
#'
#' @param x a \code{trajectory} object
#' @param dt frequency of output: 'month', 'season', 'quarter' (same as 'season') or 'year'
#' @param dx resolution in longitude direction (unit: degrees)
#' @param dy resolution in latitude direction (unit: degrees)
#' @param plot if TRUE show plot of results
#' @param radius radius within which to look for trajectories for each grid point (unit: m)
#' @param it a time index, e.g., a range of years: c(1984,2019)
#' @param is a spatial index, e.g., a list with longitude and latitude ranges: list(lon=c(0,45), lat=c(45,70))
#' @param param parameter to calculate field of; if NULL calculate track density (for other options, see \code{colnames(x)})
#' @param type 'track', 'genesis', or 'lysis'
#' @param longname name of variable
#' @param verbose a boolean; if TRUE print information about progress
#' @param \dots additional arguments
#'
#' @return a \code{field} object
#'
#' @aliases as.field.events events2density
#' @seealso as.field CCI track.events 
#'
#' @importFrom utils tail
#'
#' @export
events2field <- function(x,verbose=FALSE,...) {
  if (verbose) print("events2field")
  y <- events2density(x,verbose=verbose,...)
  invisible(y)  
}

#' @export
events2density <- function(x,dt="month",dx=1,dy=1,plot=FALSE,
                           lons=NULL,lats=NULL,it=NULL,is=NULL,
                           radius=5e5,unitarea=NULL,type="track",
                           param=NULL,longname=NULL,verbose=FALSE,...) {
  if (verbose) print("events2density")
  ok <- !is.na(x["time"][[1]]) & !is.na(x["lon"][[1]]) & !is.na(x["lat"][[1]])
  x <- subset(x,it=ok)
  y <- subset(x,it=it,is=is)
  dlon <- mean(diff(sort(unique(x$lon))))
  if (!"trajectory" %in% colnames(y)) y <- track(y)
  if(is.null(lons)) lons <- y["lon"][[1]]
  if(is.null(lats)) lats <- y["lat"][[1]]
  if(is.null(dx)) dx <- min(diff(sort(unique(lons))))
  if(is.null(dy)) dy <- min(diff(sort(unique(lats))))
  lons <- round(lons/dx)*dx
  lons <- seq(min(lons),max(lons),dx)
  lats <- round(lats/dy)*dy
  lats <- seq(min(lats),max(lats),dy)
  if (verbose) print("calculate event density")
  if(is.null(attr(y,"calendar"))) calendar <- "gregorian" else calendar <- attr(x,"calendar")
  if (requireNamespace("PCICt", quietly = TRUE)) {
    d <- PCICt::as.PCICt(paste(y$date,y$time),format="%Y%m%d %H",cal=calendar)
  } else {
    d <- as.POSIXct(paste(y$date,y$time),format="%Y%m%d %H",cal=calendar)
  }
  if (grepl('day',dt)) {
    if (verbose) print("daily")
    if (requireNamespace("PCICt", quietly = TRUE)) {
      d <- PCICt::as.PCICt(format(d,"%Y-%m-%d"),cal=attr(y,"calendar"))
    } else {
      d <- as.POSIXct(format(d,"%Y-%m-%d"),cal=attr(y,"calendar"))
    }
    dvec <- seq(min(d),max(d),by="day")
    unit <- 'tracks/day/unit~area'
  } else if (grepl('month',dt)) {
    if (verbose) print("monthly")
    d <- as.Date(paste(format(d,"%Y-%m"),"-01",sep=""))
    dvec <- seq(min(d),max(d),by="month")
    calendar <- "gregorian"
    unit <- 'tracks/month/unit~area'
  } else if (grepl('season',dt) | grepl('quarter',dt)) {
    if (verbose) print("seasonal")
    d <- as.Date(as.yearqtr(paste(format(d,"%Y-%m"),"-01",sep=""),format="%Y-%m-%d"))
    dvec <- seq(min(d),max(d),by="quarter")
    calendar <- "gregorian"
    unit <- 'tracks/season/unit~area'
  } else if (grepl('year',dt) | grepl('annual',dt)) {
    if (verbose) print("annual")
    #d <- as.Date(paste(year(strptime(y["date"][[1]],"%Y%m%d")),"-01-01",sep=""))
    d <- as.Date(as.yearqtr(paste(format(d,"%Y-"),"01-01",sep=""),format="%Y-%m-%d"))
    dvec <- seq(min(d),max(d),by="year")
    calendar <- "gregorian"
    unit <- 'tracks/year/unit~area'
  } else if (grepl('hour',dt)) {
    if (verbose) print("hourly")
    #d <- as.POSIXct(strptime(paste(y["date"][[1]],y["time"][[1]]),
    #                         format="%Y%m%d %H"))
    dh <- min(diff(sort(unique(y$time))))
    dvec <- seq(min(d),max(d),by=dh*60*60)
    unit <- paste('tracks/',dh,'hours/unit~area',sep='')
  } else {
    print(paste("WARNING! invalid time resolution dt",dt))
  }
  X <- array(rep(0,),dim=c(length(dvec),length(lons),length(lats)))
  if (verbose) print("looping...")
  t1 <- Sys.time()
  pb <- txtProgressBar(style=3)
  for (i in 1:length(dvec)) {
    setTxtProgressBar(pb,i/length(dvec))
    yi <- subset.events(y,it=(d==dvec[i]))
    if (!is.null(dim(yi)) & dim(yi)[1]>0) {
      di <- trackdensity(yi["lon"][[1]],yi["lat"][[1]],radius=radius,
              yi["trajectory"][[1]],dx=dx,dy=dy,type=type,
              verbose=verbose)
      for(j in 1:length(di$lat)) {
        X[dvec==dvec[i],lons==di$lon[j],lats==di$lat[j]] <- di$density[j]
      }
    }
  }
  #Y <- X
  area <- pi*radius^2
  if(is.null(unitarea)) unitarea <- pi*radius^2
  Y <- X*unitarea/area
  t2 <- Sys.time()
  if (verbose) print(paste('Calculating the density took',
                round(as.numeric(t2-t1,units="secs")),'s'))
  d <- dim(X)
  dim(Y) <- c(d[1],d[2]*d[3])
  if(type %in% c("track","trajectory")) {
    if(is.null(param)) param <- "track~density"
    if(is.null(longname)) longname <- paste("track density",attr(x,'variable'),sep=', ')
  } else if(type %in% c("genesis","start")) {
    if(is.null(param)) param <- "genesis~density"
    if(is.null(longname)) longname <- paste("genesis density",attr(x,'variable'),sep=', ')      
  } else if(type %in% c("lysis","end")) {
    if(is.null(param)) param <- "track~density"
    if(is.null(longname)) longname <- paste("lysis density",attr(x,'variable'),sep=', ')
  }
  
  Y <- as.field(Y,index=dvec,lon=lons,lat=lats,
          unit=unit,longname=longname,param=param,
          quality=attr(x,'quality'),src=attr(x,'source'),
          url=attr(x,'URL'),reference=attr(x,'reference'),
          info=attr(x,'info'),calendar=calendar,
          method=attr(x,'method'),aspect=attr(x,'aspect'))
  attr(Y,"unitarea") <- unitarea
  if(plot) {
    ## compare count and density:
    is <- list(lon=c(-20,20),lat=c(50,70))
    N1 <- count.events(subset(y,is=is))
    N2 <- density2count(Y,is=is)
    plot(N2,map.type="rectangle",col="blue",lty=2)
    lines(N1,col="black",lty=1)
    legend("topleft",col=c("black","blue"),lty=c(1,2),
           legend=c("storm count","density2count"))
  }
  invisible(Y)
}

area.lonlat <- function(lons,lats,a=6.371e06) {
  N <- length(lons)
  angles <- rep(NA,N)
  for (i in seq(N)) {
    lati <- roll(lats, i)
    loni <- roll(lons, i)
    beta1 <- greatcircbearing(loni[2], lati[2], loni[1], lati[1])
    beta2 <- greatcircbearing(loni[2], lati[2], loni[3], lati[3])
    angles[i] <- acos(cos(-beta1)*cos(-beta2) + sin(-beta1)*sin(-beta2))
  }
  area <- (sum(angles) - (N-2)*pi)*a**2
}

greatcircbearing <- function(lon1, lat1, lon2, lat2) {
    dlon <- lon1 - lon2
    d2r <- pi/180
    s <- cos(d2r*lat2)*sin(d2r*dlon)
    c <- cos(d2r*lat1)*sin(d2r*lat2) - sin(lat1*d2r)*cos(d2r*lat2)*cos(d2r*dlon)
    return(atan2(s, c))
}

roll <- function( x , n ){
  if( n == 0 )
    return( x )
  c( tail(x,n) , head(x,-n) )
}


## cyclonedensity <- function(lons,lats,radius=NULL,dx=NULL,dy=NULL,
##                           R=6371,verbose=FALSE) {
##   if (!is.null(dx)) {
##     lons <- round(lons/dx)*dx
##   } else {
##     dx <- min(diff(sort(unique(lons))))
##   }
##   if (!is.null(dy)) {
##     lats <- round(lats/dy)*dy
##   } else {
##     dy <- min(diff(sort(unique(lats))))
##   }
##   fn <- function(x,y,r,dx,dy) {
##     xvec <- seq(round(-180/dx)*dx,round(180/dx)*dx,dx)
##     yvec <- seq(round(-90/dy)*dy,round(90/dy)*dy,dy)
##     xx <- as.vector(sapply(xvec,function(x) rep(x,length(yvec))))
##     yy <- rep(yvec,length(xvec))
##     i <- mapply(function(a,b,d) distAB(a,b,xx,yy)<d,x,y,r)
##     rx <- unlist(apply(i,2,function(j) xx[j]))
##     ry <- unlist(apply(i,2,function(j) yy[j]))
##     ok <- !is.na(rx) & !is.na(ry); rx <- rx[ok]; ry <- ry[ok]
##     hits <- as.data.frame(table(lon=rx,lat=ry))
##     hits <- hits[hits$Freq>0,]
##     hx <- factor2numeric(hits$lon)
##     hy <- factor2numeric(hits$lat)
##     A <- dx*(pi/180)*R**2*abs(sin(min(hy+dy/2,90)*pi/180)-
##                            sin((hy-dy/2)*pi/180))
##     d <- hits$Freq/A*1E6
##     d[is.infinite(d)] <- NA
##     invisible(cbind(hx,hy,d))
##   }
##   if (is.null(radius)) radius <- 5E5
##   dens <- fn(lons,lats,radius,dx,dy)
##   hlons <- dens[,]
##   hlats <- dens[,2]
##   d <- dens[,3]
##   X <- data.frame(lon=dens[,"hx"],lat=dens[,"hy"],density=dens[,"d"])
##   invisible(X)
## }
