
# TODO:
# 1. Add required packages as "depends"
# 2. And/Or
# 3. More geolocation options; other types (region, etc etc -- implement all)
#   -- Allow searching...
#   --SEE HERE: https://developers.facebook.com/docs/marketing-api/audiences/reference/basic-targeting
# 4. locales
# 5. Function for -- get suggested radius: https://developers.facebook.com/docs/marketing-api/audiences/reference/targeting-search#locale
# 6. See very bottom: https://developers.facebook.com/docs/marketing-api/audiences/reference/targeting-search#geo
# 7. Allow entering multiple keys (token, version, creation_act must be same length). Here, we just iterate through them??
# -- Or maybe just give an example? For example, loop over location?
# 8. Add examples

library(dplyr)
library(lubridate)
library(jsonlite)
library(httr)
library(stringr)
if(F){
  roxygen2::roxygenise("~/Documents/Github/rSocialWatcher")
}

# Helper functions -------------------------------------------------------------
is_null_or_na <- function(x){
  # Return TRUE if x is NULL or NA; FALSE otherwise
  
  out <- FALSE
  
  if(is.null(x)) out <- TRUE
  
  if(!is.null(x)){
    if(TRUE %in% is.na(x)) out <- TRUE
  }
  
  return(out)
}

# Main functions ---------------------------------------------------------------

# TODO: Instead of "demographics", maybe "relationship_statuses", etc.
#' Get Facebook Parameter IDs
#'
#' This function returns dataframes of parameters for behaviors, demographics, 
#' and interests. The dataframes contain ids that can be used in the 
#' query_fb_marketing_api function.
#'
#' @param type Type of data; either "behaviors", "demographics", "interests", or "locales"
#' @param version Facebook Marketing API version; for example, "v14.0"
#' @param token Facebook Marketing API token
#' 
#' @return Dataframe with parameter IDs and descriptions.
#' @export
get_fb_parameters <- function(type,
                              version,
                              token,
                              q = NULL,
                              country_code = NULL,
                              region_id = NULL,
                              key=NULL){
  
  # Checks ---------------------------------------------------------------------
  #if(!(type %in% c("behaviors", "demographics", "interests", "locales"))) stop("Invalid type; type must be either: 'behaviors', 'demographics', 'interests', or 'locales'")
  
  # Call API -----------------------------------------------------------------
  if(type %in% c("behaviors", "demographics", "interests")){
    out_df <- GET(
      paste0("https://graph.facebook.com/",version,"/search"),
      query=list(
        type='adTargetingCategory',
        class=type,
        access_token=token,
        limit=2000
      )) %>% content(as="text") %>% fromJSON %>%. [[1]]
  } else if (type %in% "locales"){
    out_df <- GET(
      paste0("https://graph.facebook.com/",version,"/search"),
      query=list(
        type='adlocale',
        access_token=token,
        limit=2000
      )) %>% content(as="text") %>% fromJSON %>%. [[1]]
  } else if (type %in% "job_titles"){
    out_df <- GET(
      paste0("https://graph.facebook.com/",version,"/search"),
      query=list(
        type='adworkposition',
        q=q,
        access_token=token,
        limit=5000
      )) %>% content(as="text") %>% fromJSON %>%. [[1]]
  } else if (type %in% "education_major"){
    if(is.null(q)) stop("'q' required")
    out_df <- GET(
      paste0("https://graph.facebook.com/",version,"/search"),
      query=list(
        type='adeducationmajor',
        q=q,
        access_token=token,
        limit=5000
      )) %>% content(as="text") %>% fromJSON %>%. [[1]]
  } else if (type %in% c("country", "country_group")){
    out_df <- GET(
      paste0("https://graph.facebook.com/",version,"/search"),
      query=list(
        location_types=type,
        type='adgeolocation',
        access_token=token,
        limit=300
      )) %>% content(as="text") %>% fromJSON %>%. [[1]]
  } else if (type %in% c("region",
                         "large_geo_area",
                         "medium_geo_area",
                         "small_geo_area",
                         "metro_area",
                         "city",
                         "subcity",
                         "neighborhood",
                         "subneighborhood",
                         "zip",
                         "geo_market",
                         "electoral_district")){
    
    if(type %in% c("zip")){
      if(is.null(q)){
        #stop("Parameter 'q' required")
      }
    }
    
    out_df <- GET(
      paste0("https://graph.facebook.com/",version,"/search"),
      query=list(
        location_types=type,
        type='adgeolocation',
        q=q,
        region_id=region_id,
        country_code=country_code,
        key=key,
        access_token=token,
        limit=3000
      )) %>% content(as="text") %>% fromJSON %>%. [[1]]
  } 
  
  return(out_df)
}

query_fb_marketing_api_1call <- function(location_type,
                                         lat_lon = NULL,
                                         radius = NULL,
                                         radius_unit = NULL,
                                         country_code = NULL,
                                         country_group = NULL,
                                         location_keys = NULL,
                                         locales = NULL,
                                         behavior = NULL,
                                         interest = NULL,
                                         relationship_statuses = NULL, 
                                         life_events = NULL, 
                                         industries = NULL, 
                                         income = NULL, 
                                         family_statuses = NULL,
                                         education_statuses = NULL,
                                         user_os = NULL,
                                         wireless_carrier = NULL,
                                         gender = c(1,2),
                                         age_min = 18,
                                         age_max = 65,
                                         version, 
                                         creation_act, 
                                         token,
                                         sleep_time = 20,
                                         show_result = T,
                                         add_query = F,
                                         add_query_hide_credentials = T){
  
  # Query Facebook Marketing API
  # ARGs:
  # location_type: "coordinates" or "country"
  
  # --loc_i: Numeric id of which row to use from `coords_df`
  # --coords_df: Dataframe with latitude and longitude variables
  # --parameters_df_i: Dataframe with parameters
  # --version: Facebook marketing API verion
  # --creation_act: Creation act (associated with API key/account)
  # --token: API token/key
  
  # Checks ---------------------------------------------------------------------
  if(is.null(location_type)){
    stop("'location_type' required. Must be either 'coordinates' or 'country'")
  }
  
  if(!(location_type %in% c("coordinates", "country"))){
    # stop("'location_type' must be either 'coordinates' or 'country'")
  }
  
  if(location_type == "coordinates"){
    
    if(length(lat_lon) != 2 ) stop("'lat_lon' must be a vector of length 2, with latitude then longitude")
    #if(is.null(latitude))    stop("Must enter numeric value for 'latitude'")
    #if(is.null(longitude))   stop("Must enter numeric value for 'longitude'")
    if(is.null(radius))      stop("Must enter numeric value for 'radius'")
    if(is.null(radius_unit)) stop("Must enter 'kilometer' or 'mile' for 'radius_unit'")
  }
  
  if(location_type == "countries"){
    if(is.null(country_code)) stop("Must enter value for 'country_code'")
  }
  
  if(!is.null(radius_unit)){
    if(!(radius_unit %in% c("mile", "kilometer"))) stop("Invalid 'radius_unit'; if specify radius_unit, must be either 'mile' or 'kilometer'")
  }
  
  # Check internet -------------------------------------------------------------
  # Stall if not connected to internet
  while(!curl::has_internet()){ Sys.sleep(5); print("Looking for internet")}
  
  # Prep parameters ------------------------------------------------------------
  if(is_null_or_na(behavior)){
    behavior_param <- NULL
  } else{
    behavior_param <- paste0("{'id':", behavior, "}") %>% paste(collapse = ",")
  }
  
  if(is_null_or_na(interest)){
    interest_param <- NULL
  } else{
    interest_param <- paste0("{'id':", interest, "}") %>% paste(collapse = ",")
  }
  
  if(is_null_or_na(relationship_statuses)){
    relationship_statuses_param <- NULL
  } else{
    relationship_statuses_param <- relationship_statuses %>% paste(collapse = ",")
  }
  
  if(is_null_or_na(life_events)){
    life_events_param <- NULL
  } else{
    life_events_param <- paste0("{'id':", life_events, "}") %>% paste(collapse = ",")
  }
  
  if(is_null_or_na(industries)){
    industries_param <- NULL
  } else{
    industries_param <- paste0("{'id':", industries, "}") %>% paste(collapse = ",")
  }
  
  if(is_null_or_na(income)){
    income_param <- NULL
  } else{
    income_param <- paste0("{'id':", income, "}") %>% paste(collapse = ",")
  }
  
  if(is_null_or_na(family_statuses)){
    family_statuses_param <- NULL
  } else{
    family_statuses_param <- paste0("{'id':", family_statuses, "}") %>% paste(collapse = ",")
  }
  
  if(is_null_or_na(education_statuses)){
    education_statuses_param <- NULL
  } else{
    education_statuses_param <- education_statuses %>% paste(collapse = ",")
  }
  
  if(is_null_or_na(user_os)){
    user_os_param <- NULL
  } else{
    if(length(user_os) > 1) stop("Only accepts vector of length 1 for user_os (right now)")
    user_os_param <- paste0("'", user_os, "'")
  }
  
  if(is_null_or_na(wireless_carrier)){
    wireless_carrier_param <- NULL
  } else{
    if(length(wireless_carrier) > 1) stop("Only accepts vector of length 1 for wireless_carrier (right now)")
    wireless_carrier_param <- paste0("'", wireless_carrier, "'")
  }
  
  if(location_type == "places"){
    if(is.null(radius))      stop("'radius' not spacified. When location_type = 'places', must specify radius (and radius_unit).")
    if(is.null(radius_unit)) stop("'radius_unit' not spacified. When location_type = 'places', must specify radius_unit (and radius).")
  }
  
  if(location_type %in% c("countries","regions","zips","geo_markets","electoral_district","country_groups")){
    if(!is.null(radius))      stop(paste0("'radius' parameter not allowed when location_type = '", location_type, "'"))
    if(!is.null(radius_unit)) stop(paste0("'radius_unit' parameter not allowed when location_type = '", location_type, "'"))
  }
  
  if(location_type %in% c("coordinates","places")){
    
    if(radius_unit == "mile"){
      if(radius > 50)   stop("Radius too large; radius must be between 0.63 and 50 miles when location_type = '",location_type,"'.")
      if(radius < 0.63) stop("Radius too small; radius must be between 0.63 and 50 miles when location_type = '",location_type,"'.")
    }
    
    if(radius_unit == "kilometer"){
      if(radius > 80) stop("Radius too large; radius must be between 1 and 80 kilometers when location_type = '",location_type,"'.")
      if(radius < 1)  stop("Radius too small; radius must be between 1 and 80 kilometers when location_type = '",location_type,"'.")
    }
    
  }
  
  if(location_type %in% c("cities")){
    
    if(radius_unit == "mile"){
      if(radius > 50) stop("Radius too large; if specify radius, radius must be between 0.63 and 50 miles when location_type = '",location_type,"'.")
      if(radius < 10) stop("Radius too small; if specify radius, radius must be between 0.63 and 50 miles when location_type = '",location_type,"'.")
    }
    
    if(radius_unit == "kilometer"){
      if(radius > 80) stop("Radius too large; if specify radius, radius must be between 1 and 80 kilometers when location_type = '",location_type,"'.")
      if(radius < 17) stop("Radius too small; if specify radius, radius must be between 1 and 80 kilometers when location_type = '",location_type,"'.")
    }
    
  }
  
  gender_param <- gender %>% paste(collapse = ",")
  
  # Make Query -----------------------------------------------------------------
  if(location_type == "coordinates"){
    latitude  <- lat_lon[1]
    longitude <- lat_lon[2]
    
    # TODO: Maybe location_type doesn't need to be here?? As should be another parameter? Or put in all?
    query_location <- paste0("'geo_locations':{'location_types':['home'],'custom_locations':[{'latitude':",
                             latitude %>% substring(1,7),",",
                             "'longitude':",
                             longitude %>% substring(1,7),",",
                             "'radius':",
                             radius,",",
                             "'distance_unit':'",radius_unit,"'}]},")
  } else if (location_type %in% c("countries", "country_groups")){
    query_location <- paste0("'geo_locations':{'",location_type,"':[",
                             paste0("'",country_code,"'") %>% paste(collapse = ","),
                             "]},")
  } else if (location_type %in% c("regions","electoral_districts","zips","geo_markets")){
    query_location <- paste0("'geo_locations':{'",location_type,"':[",
                             paste0("{'key':'",location_keys,"'}") %>% paste(collapse = ","),
                             "]},")
  } else if ( (location_type %in% c("cities")) & is.null(radius)){
    query_location <- paste0("'geo_locations':{'",location_type,"':[",
                             paste0("{'key':'",location_keys,"'}") %>% 
                               paste(collapse = ","),
                             "]},")
  } else if ( (location_type %in% c("cities", "places")) & !is.null(radius)){
    query_location <- paste0("'geo_locations':{'",location_type,"':[",
                             paste0("{'key':'",location_keys,"','radius':",radius,",'distance_unit':'",radius_unit,"'}") %>% 
                               paste(collapse = ","),
                             "]},")
  }
  
  query <- paste0("https://graph.facebook.com/",version,
                  "/act_",creation_act,
                  "/delivery_estimate?access_token=",token,
                  "&include_headers=false&method=get&pretty=0&suppress_http_code=1&method=get&optimization_goal=REACH&pretty=0&suppress_http_code=1&targeting_spec={",
                  query_location,
                  ifelse(is.null(behavior_param), "", 
                         paste0("'behaviors':[", behavior_param, "],")), 
                  ifelse(is.null(interest_param), "", 
                         paste0("'interests':[", interest_param, "],")), 
                  ifelse(is.null(relationship_statuses_param), "", 
                         paste0("'relationship_statuses':[", relationship_statuses_param, "],")), 
                  ifelse(is.null(life_events_param), "", 
                         paste0("'life_events':[", life_events_param, "],")), 
                  ifelse(is.null(industries_param), "", 
                         paste0("'industries':[", industries_param, "],")), 
                  ifelse(is.null(income_param), "", 
                         paste0("'income':[", income_param, "],")), 
                  ifelse(is.null(family_statuses_param), "", 
                         paste0("'family_statuses':[", family_statuses_param, "],")), 
                  ifelse(is.null(education_statuses_param), "", 
                         paste0("'education_statuses':[", education_statuses_param, "],")), 
                  ifelse(is.null(user_os_param), "", 
                         paste0("'user_os':[", user_os_param, "],")), 
                  ifelse(is.null(wireless_carrier_param), "", 
                         paste0("'wireless_carrier':[", wireless_carrier_param, "],")), 
                  "'genders':[",gender_param,"],", 
                  "'age_min':",age_min,",",
                  "'age_max':",age_max, 
                  "}")
  
  # Make query and prep dataframe with results and parameter
  try_api_call <- TRUE
  while(try_api_call){
    try_api_call <- FALSE
    
    query_val_df <- tryCatch({
      
      query_val <- url(query) %>% fromJSON
      
      #### If there is no error
      if(is.null(query_val$error)){
        
        ## Marketing info to dataframe
        query_val_df <- query_val$data
        query_val_df$daily_outcomes_curve <- NULL
        
        ## Add parameter info
        # TODO: If "", NA or NULL, remove variable
        query_val_df$location_type         <- location_type
        query_val_df$behavior              <- behavior              %>% paste(collapse = ",")
        query_val_df$interest              <- interest              %>% paste(collapse = ",")
        query_val_df$relationship_statuses <- relationship_statuses %>% paste(collapse = ",")
        query_val_df$life_events           <- life_events           %>% paste(collapse = ",")
        query_val_df$industries            <- industries            %>% paste(collapse = ",")
        query_val_df$income                <- income                %>% paste(collapse = ",")
        query_val_df$family_statuses       <- family_statuses       %>% paste(collapse = ",")
        query_val_df$education_statuses    <- education_statuses    %>% paste(collapse = ",")
        query_val_df$user_os               <- user_os               %>% paste(collapse = ",")
        query_val_df$wireless_carrier      <- wireless_carrier      %>% paste(collapse = ",")
        query_val_df$gender                <- gender                %>% paste(collapse = ",")
        query_val_df$age_min               <- age_min
        query_val_df$age_max               <- age_max
        query_val_df$location_type         <- location_type
        query_val_df$radius                <- radius
        query_val_df$radius_unit           <- radius_unit
        query_val_df$country_code          <- country_code  %>% paste(collapse = ",")
        query_val_df$country_group         <- country_group  %>% paste(collapse = ",")
        query_val_df$location_keys         <- location_keys %>% paste(collapse = ",")
        
        if(location_type == "coordinates"){
          query_val_df$latitude  <- latitude
          query_val_df$longitude <- longitude
        }
        
        ## Add time
        query_val_df$api_call_time_utc <- Sys.time() %>% with_tz(tzone = "UTC")
        
        if(add_query){
          query_val_df$query <- query
          if(add_query_hide_credentials){
            query_val_df$query <- query_val_df$query %>%
              str_replace_all(paste0("act_", creation_act), "act_CREATION_ACT") %>%
              str_replace_all(paste0("access_token=", token), "access_token=TOKEN")
          }
          
        } 
        
        ## If no entry in dataframe ("" or NA), then remove the variable
        for(var in names(query_val_df)){
          if(is.na(query_val_df[[var]]))  query_val_df[[var]] <- NULL
          if(query_val_df[[var]] %in% "") query_val_df[[var]] <- NULL
        }
        
        ## Print result and sleep (sleep needed b/c of rate limiting)
        #if(show_result){
        #  print(query_val_df)
        #}
        
        if(show_result){
          print(query_val_df$estimate_mau_upper_bound)
        }
        
        ## Sleep
        Sys.sleep(sleep_time) 
        
        #### If there is an error, print the error and make output null  
      } else{
        
        if(!is.null(query_val$error$code)){
          if((query_val$error$code == 80004)){
            try_api_call <- TRUE
            print("Too many calls, so pausing for 30 seconds then will try the query again; will only move to the next API query after the current query has successfully been called.")
            Sys.sleep(30)
          } 
        }
        
        query_val_df <- ""
        
        # Sometimes lat/lon is not in a valid location. We still create a dataframe
        # for those queries.
        if(query_val$error$error_user_title == "Incorrect Location Format"){
          query_val_df <- data.frame(ERROR = "Incorrect Location Format")
        } else{
          query_val_df <- NULL
        }
        
      }
      
      query_val_df
      
    },error = function(e){
      print("ERROR")
      try_api_call <- F
      Sys.sleep(0.1)
      return(NULL)
    })
  }
  
  return(query_val_df)
}

#' Query Facebook Marketing API
#' ## Location
#' @param location_type Either `"coordinates"` (for buffer around single point) or `"country"`
#' ### If location_Type = "coordinates"
#' @param lat_lon Coordinates, c(lat, lon). For example, `c(38.90, -77.01)`
#' @param radius Radius around coordinate
#' @param radius_unit Unit for radius; either `"kilometer"` or `"mile"`
#' ### If location_type = "country" 
#' @param country_code Country ISO2; for example, `"US"`.
#' ## Other location??
#' @param locales Words
#' ## Parameters. These are optional. If nothing specified, then searches for all users.
#' @param behavior Vector of behavior IDs. If multiple, uses `OR` condition; for example, `behavior = c(6002714895372, 6008297697383)` will target users who are either frequent travelers or returned from travels 2 weeks ago. Use `get_fb_parameters(type = "behaviors")` to get dataframe with IDs and descriptions. 
#' @param interest Vector of interest IDs. If multiple, uses `OR` condition; for example, `interest = c(6003349442621, 6003139266461)` will target users who are interested in either entertainment or movies. Use `get_fb_parameters(type = "interests")` to get dataframe with IDs and descriptions. 
#' @param relationship_statuses Vector of relationship status IDs. If multiple, uses `OR` condition; for example, `relationship_statuses = c(3,4)` targets those who are married or engaged. See `relationship_statuses` in the [Advanced Targeting Documentation](https://developers.facebook.com/docs/marketing-api/audiences/reference/advanced-targeting) to see relationship status ID options with descriptions. 
#' @param life_events Vector of life event IDs. If multiple, uses `OR` condition; for example, `life_events = c(6005149512172, 6005149512172)` targets users who recently moved or are in a new job. Use `get_fb_parameters(type = "demographics")` to get dataframe with IDs and descriptions. 
#' @param industries Vector of industries IDs. If multiple, uses `OR` condition; for example, `industries = c(6008888980183, 6008888972183)` targets users who work in sales or legal services. Use `get_fb_parameters(type = "demographics")` to get dataframe with IDs and descriptions. 
#' @param income Vector of income IDs. If multiple, uses `OR` condition; for example, `income = c(6107813553183, 6107813554583)` targets users with a household income in the top 10%-25% or 25%-50% of ZIP codes (US). Use `get_fb_parameters(type = "demographics")` to get dataframe with IDs and descriptions. 
#' @param family_statuses Vector of family status IDs. If multiple, uses `OR` condition; for example, `family_statuses = c(6023080302983, 6023005681983)` targets users who are parents with preteens or parents with teenagers. Use `get_fb_parameters(type = "demographics")` to get dataframe with IDs and descriptions. 
#' @param education_statuses Education status IDs. If multiple, uses `OR` condition; for example, `education_statuses = c(9,10)` will yeild those who report to have either a Master degree or professional degree. See `education_statuses` in the [Advanced Targeting Documentation](https://developers.facebook.com/docs/marketing-api/audiences/reference/advanced-targeting) to see education status options. 
#' @param user_os User operating systems. If multiple, uses `OR` condition; for example `user_os = ['iOS', 'Android']` targets those that use either an iOS or Android OS. See `user_os` in the [Advanced Targeting Documentation](https://developers.facebook.com/docs/marketing-api/audiences/reference/advanced-targeting) for additional details.
#' @param wireless_carrier Wireless carriet. If set to `Wifi`, then targets those connecting via a Wifi network. See `wireless_carrier` in the [Advanced Targeting Documentation](https://developers.facebook.com/docs/marketing-api/audiences/reference/advanced-targeting) for additional details.
#' @param gender Genders to target; 1 targets males and 2 targets females Default is both. See `gender` in the [Basic Targeting Documentation](https://developers.facebook.com/docs/marketing-api/audiences/reference/basic-targeting#demographics).
#' @param age_min Minimum age. Default is 18. See `age_min` in the [Basic Targeting Documentation](https://developers.facebook.com/docs/marketing-api/audiences/reference/basic-targeting#demographics).
#' @param age_max Maximum age. Default is 65. See `age_max` in the [Basic Targeting Documentation](https://developers.facebook.com/docs/marketing-api/audiences/reference/basic-targeting#demographics).
#' ## Credentials
#' @param version API version. e.g., "v14.0"
#' @param creation_act Facebook creation act
#' @param token Facebook API token
#' ## Scraping parameters
#' @param sleep_time words
#' @param show_result words
#' ## Return query text as variable in returned dataframe
#' @param add_query If `TRUE`, add query text as variable in returned dataframe 
#' @param add_query_hide_credentials If `TRUE` (and `add_query` is `TRUE`), hide the `creation_act` and `token` from the query text returned in the dataframe
#' 
#' @return Dataframe that includes (1) daily and monthly active users and (2) parameter values
#' 
#' @details FOR LOOP, USE LISTS. BUT JUST CAN'T LIST ON LOCATION TYPE.
#' @seealso [get_fb_parameters()] To get IDs and descriptions for behaviors, demographics, interests, and locales.
#' @export
query_fb_marketing_api <- function(location_type,
                                   lat_lon = NULL,
                                   radius = NULL,
                                   radius_unit = NULL,
                                   country_code = NULL,
                                   country_group = NULL,
                                   location_keys = NULL,
                                   locales = NULL,
                                   behavior = NULL,
                                   interest = NULL,
                                   relationship_statuses = NULL, 
                                   life_events = NULL, 
                                   industries = NULL, 
                                   income = NULL, 
                                   family_statuses = NULL,
                                   education_statuses = NULL,
                                   user_os = NULL,
                                   wireless_carrier = NULL,
                                   gender = c(1,2),
                                   age_min = 18,
                                   age_max = 65,
                                   version, 
                                   creation_act, 
                                   token,
                                   sleep_time = 1,
                                   show_result = T,
                                   add_query = F,
                                   add_query_hide_credentials = T){
  
  # Checks -----------------------------------------------------------------------
  if(length(location_type) != 1) stop("'location_type' must be a vector of length one, either 'coordinates' or 'country'; only one option allowed")
  
  # Convert param inputs to list -------------------------------------------------
  convert_to_list <- function(x){
    # Converts to list if not a list
    if(!is.list(x)) x <- list(x)
    return(x)
  }
  
  lat_lon               <- lat_lon               %>% convert_to_list()
  radius                <- radius                %>% convert_to_list()
  radius_unit           <- radius_unit           %>% convert_to_list()
  country_code          <- country_code          %>% convert_to_list()
  country_group         <- country_group         %>% convert_to_list()
  location_keys         <- location_keys         %>% convert_to_list()
  locales               <- locales               %>% convert_to_list()
  behavior              <- behavior              %>% convert_to_list()
  interest              <- interest              %>% convert_to_list()
  relationship_statuses <- relationship_statuses %>% convert_to_list()
  life_events           <- life_events           %>% convert_to_list()
  industries            <- industries            %>% convert_to_list()
  income                <- income                %>% convert_to_list()
  family_statuses       <- family_statuses       %>% convert_to_list()
  education_statuses    <- education_statuses    %>% convert_to_list()
  user_os               <- user_os               %>% convert_to_list()
  wireless_carrier      <- wireless_carrier      %>% convert_to_list()
  gender                <- gender                %>% convert_to_list()
  age_min               <- age_min               %>% convert_to_list()
  age_max               <- age_max               %>% convert_to_list()
  
  # Length parameter inputs to same length ---------------------------------------
  # n_param_combn <- length(lat_lon) * 
  #   length(radius) *
  #   length(radius_unit) *
  #   length(country_code) *
  #   length(country_group) *
  #   length(location_keys) *
  #   length(locales) *
  #   length(behavior) *
  #   length(interest) *
  #   length(relationship_statuses) *
  #   length(life_events) *
  #   length(industries) *
  #   length(income) *
  #   length(family_statuses) *
  #   length(education_statuses) *
  #   length(user_os) *
  #   length(wireless_carrier) *
  #   length(gender) *
  #   length(age_min) *
  #   length(age_max)
  
  
  param_grid_df <- expand.grid(lat_lon               = lat_lon,
                               country_code          = country_code,
                               country_group         = country_group,
                               location_keys         = location_keys,
                               radius                = radius,
                               radius_unit           = radius_unit,
                               locales               = locales,
                               behavior              = behavior,
                               interest              = interest,
                               relationship_statuses = relationship_statuses,
                               life_events           = life_events,
                               industries            = industries,
                               income                = income,
                               family_statuses       = family_statuses,
                               education_statuses    = education_statuses,
                               user_os               = user_os,
                               wireless_carrier      = wireless_carrier,
                               gender                = gender,
                               age_min               = age_min,
                               age_max               = age_max)
  
  # Length parameter inputs to same length -------------------------------------
  out_df <- mapply(query_fb_marketing_api_1call,
                   lat_lon               = param_grid_df$lat_lon,
                   radius                = param_grid_df$radius,
                   radius_unit           = param_grid_df$radius_unit,
                   country_code          = param_grid_df$country_code,
                   country_group         = param_grid_df$country_group,
                   location_keys         = param_grid_df$location_keys,
                   locales               = param_grid_df$locales,
                   behavior              = param_grid_df$behavior,
                   interest              = param_grid_df$interest,
                   relationship_statuses = param_grid_df$relationship_statuses,
                   life_events           = param_grid_df$life_events,
                   industries            = param_grid_df$industries,
                   income                = param_grid_df$income,
                   family_statuses       = param_grid_df$family_statuses,
                   education_statuses    = param_grid_df$education_statuses,
                   user_os               = param_grid_df$user_os,
                   wireless_carrier      = param_grid_df$wireless_carrier,
                   gender                = param_grid_df$gender,
                   age_min               = param_grid_df$age_min,
                   age_max               = param_grid_df$age_max,
                   MoreArgs = list(location_type = location_type,
                                   sleep_time    = sleep_time,
                                   show_result   = show_result,
                                   version       = version,
                                   creation_act  = creation_act,
                                   token         = token),
                   SIMPLIFY = F
  ) %>% 
    bind_rows()
  
}

