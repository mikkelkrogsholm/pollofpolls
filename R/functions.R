#' Download raw polls
#'
#' Downloads raw polls from Erik Gahners github repo. Downloads all but only
#' save the latest xx days as set by the day parameter
#'
#' @param days keeps only polls that are equal to or younger than the days
#'     parameter.
#'
#' @return tibble
#'
#' @export
#' @importFrom magrittr %>%
pp_get_raw_polls <- function(days = 28){

  # We get the data from Erik Gahners repository on danish polls
  url <- "https://raw.githubusercontent.com/erikgahner/polls/master/polls.csv"
  g <-  suppressMessages(readr::read_csv(url))

  # Then I transform the data into a form that I find easier to work with
  p <- g %>%
    dplyr::select(id:n) %>%
    tidyr::gather(party, percent, -c(id, pollingfirm, year, month, day, n)) %>%
    dplyr::mutate(party = stringr::str_remove_all(party, "party_"),
           datetime = paste(year, month, day) %>% lubridate::ymd()) %>%
    dplyr::select(id, pollingfirm, datetime, n, party, percent) %>%
    dplyr::filter(datetime >= (max(datetime) - days))

  # return the data
  return(p)

}

#' Checks and recalculates the polls
#'
#' Checks the polls and recalculates them if they do not sum to 100.
#'
#' @param raw_polls the output of pp_get_raw_polls()
#' @param silent should the function run silent?
#'
#' @return tibble
#'
#' @export
#' @importFrom magrittr %>%
pp_check_raw_polls <- function(raw_polls, silent = FALSE){

  # Check that each poll sum to 100
  total_sum <- raw_polls %>%
    dplyr::group_by(id, pollingfirm) %>%
    dplyr::summarise(total_percent = sum(percent, na.rm = TRUE)) %>%
    dplyr::ungroup()

  j <- 0

  if(!silent){
    # Message the user what polls will be adjusted.
    purrr::walk(1:nrow(total_sum), function(i){
      my_poll <- total_sum[i, ]

      if(my_poll$total_percent != 100){
        message(glue::glue("The sum of the predictions do not total 100 for poll from {my_poll$pollingfirm} with poll id {my_poll$id}. Instead it totals {my_poll$total_percent}."))

        j <<- j + 1
      }

    })

    if(j == 1){
      message("The poll will be recalculated so it sums to 100.")
    }

    if(j > 1){
      message("The polls will be recalculated so they sum to 100.")
    }
  }

  # Recalculate the raw polls so they sum to 100
  raw_polls <- raw_polls %>%
    dplyr::group_by(id) %>%
    dplyr::mutate(percent = percent / sum(percent, na.rm = TRUE) * 100) %>%
    dplyr::ungroup()


  # Return the data
  return(raw_polls)
}

#' Adds weights to the polls
#'
#' Calculates and adds weights to the polls
#'
#' @param checked_polls the output of pp_check_raw_polls()
#' @param pollster_rating the pollster rating. Defaults to the
#'     pp_calc_pollster_rating() function.
#'
#' @return tibble
#'
#' @export
#' @importFrom magrittr %>%
#' @importFrom stats weighted.mean
pp_add_weights <- function(checked_polls, pollster_rating = pp_calc_pollster_rating()){

  # Spread the polls
  spread_polls <- checked_polls %>% tidyr::spread(party, percent)

  # Add recency weight
  # This weight favors polls that are more recent. It is pretty simple and
  # creates a weight that is 1 divided by the square of the days since the
  # most recent poll plus 1. I use the square so the weight does not fall too
  # rapidly. This is a methological choice.
  spread_polls <- spread_polls %>%
    dplyr::mutate(days = as.integer(max(datetime) - datetime) + 1,
           wt_days = 1 / sqrt(days),
           wt_days = ifelse(is.infinite(wt_days), 1, wt_days),
           wt_days = wt_days / sum(wt_days)) %>%
    dplyr::select(-days)


  # Add sample size weight
  # This is super simple. I weight the polls by their sample size.
  spread_polls$wt_sample <- spread_polls$n / sum(spread_polls$n)

  # Add pollster rating weight
  # Here I use the precalculated pollster rating. See the
  # pp_calc_pollster_rating() for how this is done.
  spread_polls <- dplyr::left_join(spread_polls, pollster_rating, by = "pollingfirm")

  # Final weight
  # Lastly I multiply all the weights for each poll and recalculate it to sum
  # to 1.
  spread_polls <- spread_polls %>%
    dplyr::mutate(wt = wt_days * wt_sample * wt_rating,
                  wt = wt / sum(wt)) %>%
    dplyr::select(-c(wt_days, wt_sample, wt_rating))

  # Finally I return the data
  return(spread_polls)

}

#' Calculate the final poll of polls
#'
#' @param polls_with_wt the output of pp_add_weights()
#'
#' @return tibble
#'
#' @export
#' @importFrom magrittr %>%
pp_calc_poll <- function(polls_with_wt){

  # Create a list of data frame for each party
  party_splits <- polls_with_wt %>%
    tidyr::gather(party, percent, -c(id, pollingfirm, datetime, n, wt)) %>%
    split(.$party)

  # Run a loop and calculate poll numbers for each party
  pred_df <- purrr::map_dfr(party_splits, function(party_split){

    # sanity check
    # Throw a warning if the weights do not sum to 1
    if(sum(party_split$wt) != 1){
      warning(glue::glue("Weights for party '{unique(party_split$party)}' do not sum to 1"))
    }

    # Calculate predictions by calculating a weighted mean
    pred <- weighted.mean(party_split$percent, party_split$wt)

    # Calculate the error of the prediction as the mean absolute difference
    # between the weighted mean and the individual polls.
    # I also use the weights to calculate the errors since the errors of a
    # poll with a larger weight should also weigh more.
    error <- weighted.mean(abs(party_split$percent - pred), party_split$wt)

    # Finally create a tibble with the results and return it
    df <- tibble::tibble(pred, error, party = unique(party_split$party))

    return(df)
  })

}

#' Driverless poll of polls
#'
#' Combines all functions in to one driverless poll of polls function
#'
#' @return tibble
#'
#' @export
#' @importFrom magrittr %>%
pp_auto_poll_of_poll <- function(){

  # Download the raw polls
  raw_polls <- pp_get_raw_polls()

  # Do a check on the polls
  checked_polls <- pp_check_raw_polls(raw_polls)

  # Add weights to the polls
  polls_with_wt <- pp_add_weights(checked_polls)

  # Calculate the final pole
  final_poll <- pp_calc_poll(polls_with_wt)

  # Return the poll
  return(final_poll)

}

#' Calculates the pollster rating
#'
#' Based on <https://fivethirtyeight.com/features/the-polls-are-all-right/>
#' article on how to calculate a pollster rating.
#'
#' @return tibble
#'
#' @export
#' @importFrom magrittr %>%
pp_calc_pollster_rating <- function(){

  # This function is based on:
  # https://fivethirtyeight.com/features/the-polls-are-all-right/

  # Get pollinng data ----
  # We get the data from Erik Gahners repository on danish polls
  url <- "https://raw.githubusercontent.com/erikgahner/polls/master/polls.csv"
  g <-  suppressMessages(readr::read_csv(url))

  # Then I transform the data into a form that I find easier to work with
  p <- g %>%
    dplyr::select(id:n) %>%
    tidyr::gather(party, percent, -c(id, pollingfirm, year, month, day, n)) %>%
    dplyr::mutate(party = stringr::str_remove_all(party, "party_"),
           datetime = paste(year, month, day) %>% lubridate::ymd()) %>%
    dplyr::select(id, pollingfirm, datetime, n, party, percent) %>%
    dplyr::group_by(id, pollingfirm, datetime) %>%
    tidyr::nest()


  # This is the election day of the last election in Denmark
  election_date <- lubridate::ymd("2015 06 18")

  # And this is the result of the election
  result_15 <- tibble::tibble(
    party = c("a", "aa", "b", "c", "f", "i", "k", "o", "oe", "v" ),
    result = c(26.3, 4.8, 4.6, 3.4, 4.2, 7.5, .8, 21.1, 7.8, 19.5)
  )

  # We use the polls from the three weeks leading up to the election. This is
  # what fivethirtyeight does. Then I calculate the mean absolute error of the
  # pollsters polls and the final result.
  pollster_rating <- p %>%
    dplyr::filter(datetime >= election_date - 21,
                  datetime <= election_date) %>%
    tidyr::unnest() %>%
    dplyr::inner_join(result_15, elec_21, by = "party") %>%
    dplyr::select(pollingfirm, party, percent, result) %>%
    dplyr::mutate(diff = abs(percent - result)) %>%
    dplyr::group_by(pollingfirm) %>%
    dplyr::summarise(diff = mean(diff)) %>%
    dplyr::arrange(diff) %>%
    dplyr::mutate(wt = 1/diff,
           wt_rating = wt / sum(wt)) %>%
    dplyr::select(-diff, -wt)

  # Return the data
  return(pollster_rating)
}

