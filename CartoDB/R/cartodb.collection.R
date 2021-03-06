cartodb.transformGeom<-
function(option=NULL) {
    if (is.null(option)) { return('the_geom') }
    else if (option=="XY") { return('ST_X(the_geom) AS the_geom_x, ST_Y(the_geom) AS the_geom_y,null as the_geom') }
    else if (option=="WKT") { return('ST_AsText(the_geom) AS the_geom') }
    else if (option=="GeoJSON") { return('ST_AsGeoJSON(the_geom) AS the_geom') }
    else if (option=="WKB") { return('the_geom as the_geom') }
    else if (option=="the_geom") { return('the_geom') }
    else { return('ST_X(the_geom) AS the_geom_x, ST_Y(the_geom) AS the_geom_y,null as the_geom') }
}
cartodb.paramsToSql<-
function(name=NULL,geomAs=NULL,columns=NULL,omitNull=FALSE,limit=NULL){
    if (is.character(columns)){
        # replace the_geom with a processed version if asked for
        if ( 'the_geom' %in% columns) {
            if(!is.null(geomAs) && geomAs!="the_geom"){
                columns[columns=="the_geom"] = cartodb.transformGeom(geomAs)
            }
        }
        
        sql <- paste("SELECT ", paste(columns, collapse=","), " FROM ", name,sep='')
    } else {
        sql <- paste("SELECT *, NULL as the_geom_webmercator,",cartodb.transformGeom(geomAs)," FROM ", name,sep='')
    }
    if (omitNull==TRUE){
        sql <- paste(sql,"WHERE the_geom IS NOT NULL")
    }
    if (is.numeric(limit)) {
        sql <- paste(sql,"LIMIT",limit)
    }
    return(sql)
}
jsonToDataFrame <-
function(json) {
    names<-names(json[[1]])
    jsonAsVector<-lapply(json, rbind)
    col<-lapply(jsonAsVector, function(x) match(names, colnames(x)))
    fixed<-lapply(1:length(jsonAsVector), function(i) rbind(as.character(jsonAsVector[[i]][,col[[i]]])))
    df<-data.frame(do.call(rbind, fixed), stringsAsFactors=FALSE)
    names(df)<-names
    return(df)
}
cartodb.collection <-
function(name = NULL, columns = NULL, geomAs = NULL, omitNull = FALSE, limit = NULL, sql = NULL, method = "dataframe",urlOnly=FALSE) {
    if (is.character(name)){
        sql<-cartodb.paramsToSql(name=name,geomAs=geomAs,columns=columns,omitNull=omitNull,limit=limit)
    }
    if (is.character(sql)){
        url <- cartodbSqlApi()
        if (method=="GeoJSON"){
            url <- URLencode(paste(url,"format=geojson&q=",sql,sep=''))
            if (urlOnly==TRUE) return(url)
            cartodb.collection.get<-getURL(url)
        } else if(method=="dataframe"){
            url <- URLencode(paste(url,"q=",sql,sep=''))
            if (urlOnly==TRUE) return(url)
            cartodb.collection.get<-getURL(url)
            cartodb.collection.json<-fromJSON(cartodb.collection.get[[1]])
            if ( 'rows' %in% names(cartodb.collection.json)) {
                df <- jsonToDataFrame(cartodb.collection.json$rows)
                
                # remove null columns from geom transformations
                if (!is.null(name) & is.character(name)){
                    if(!is.list(columns)) {
                        if(is.null(geomAs) || geomAs!="XY"){
                            df <- df[,!(colnames(df) %in% c("the_geom_webmercator"))]
                        } else {
                            df <- df[,!(colnames(df) %in% c("the_geom","the_geom_webmercator"))]
                        }
                    }
                }
                return(df)
            } else {
                warning(cartodb.collection.json)
                return(NULL)
            }
        } else {
            return(as.character(cartodb.collection.get))
        }
    } else {
        warning("You must supply a table name")
    }
}
