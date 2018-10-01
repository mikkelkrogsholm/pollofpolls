library(magrittr)

#' Download raw polls from Gahner
#'
#' Downloads raw polls from Erik Gahners github repo. Downloads all but saves only
#' the latest xx days as set by the day parameter
#'
#' @param days keeps only polls that are equal to or younger than the days
#'     parameter.
#'
#' @return tibble
#'
#' @importFrom magrittr %>%
#' @examples
#' polls <- pp_get_raw_polls_gahner()
pp_get_raw_polls_gahner <- function(days = 28){

  # We get the data from Erik Gahners repository on danish polls
  url <- "https://raw.githubusercontent.com/erikgahner/polls/master/polls.csv"
  g <-  suppressMessages(readr::read_csv(url))

  # Then I transform the data into a form that I find easier to work with
  p <- g %>%
    dplyr::select(id:n) %>%
    tidyr::gather(party, percent, -c(id, pollingfirm, year, month, day, n)) %>%
    dplyr::mutate(party = stringr::str_remove_all(party, "party_") %>% toupper(),
                  datetime = paste(year, month, day) %>% lubridate::ymd()) %>%
    dplyr::select(pollingfirm, datetime, n, party, percent) %>%
    dplyr::filter(datetime >= (as.Date(max(datetime)) - days))

  # return the data
  return(p)

}


#' Download raw polls from Berlingske
#'
#' Downloads raw polls from Berlingske Barometer. Downloads all but saves only
#' the latest xx days as set by the day parameter
#'
#' @param days keeps only polls that are equal to or younger than the days
#'     parameter.
#'
#' @return tibble
#'
#' @importFrom magrittr %>%
#' @examples
#' polls <- pp_get_raw_polls_berlingske()
pp_get_raw_polls_berlingske <- function(days = 28){

  # We get the data from Berlingskes homepage
  month = lubridate::month(Sys.Date())

  if(month == 1){
    year <- lubridate::year(Sys.Date())
    years <- c(year, year - 1)
    b <- purrr::map_dfr(years, pollsDK::get_polls)
  } else {
    b <- pollsDK::get_polls()
  }

  # Then I select the data I need
  p <- b %>%
    dplyr::select(pollingfirm = pollster, datetime, n = respondents, party = letter, percent) %>%
    dplyr::filter(datetime >= (as.Date(max(datetime)) - days))

  # return the data
  return(p)

}


#' Download raw polls
#'
#' Downloads raw polls from either Berlingske Barometer or Erik Gahner.
#' Downloads all but saves only the latest xx days as set by the day parameter.
#'
#' @param days keeps only polls that are equal to or younger than the days
#'     parameter.
#' @param source where to get the polls? Defaults to Berlingske
#'
#' @return tibble
#'
#' @export
#' @importFrom magrittr %>%
#' @examples
#' polls <- pp_get_raw_polls_berlingske()
pp_get_raw_polls  <- function(days = 28, source = "berlingske"){

  if(source == "berlingske"){
    p <- pp_get_raw_polls_berlingske(days = days)
  }

  if(source == "gahner"){
    p <- pp_get_raw_polls_gahner(days = days)
  }

  return(p)
}
