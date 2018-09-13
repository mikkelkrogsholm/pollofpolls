#' Poll of Polls by summarising
#'
#' This method calculates the number of respondents for each party in each poll
#' by taking the total number of respondents for the poll  and multiplying it
#' with the share of each party.
#'
#' Then it pools all the respondents for each party together and all the
#' respondents from all the polls together to bassically create one massive poll.
#'
#' This poll is then used to calculate the percentages and uncertainties anew.
#'
#' @param polls a data set of polls
#' @param collapse_firm collapse multiple polls from one firm into one poll that
#'     is the mean of that firms polls?
#'
#' @return a tibble
#' @export
#' @importFrom magrittr %>%
#'
#' @examples
#' polls <- pp_get_raw_polls()
#' pp_poll_of_poll_summariser(polls)
pp_poll_of_poll_summariser <- function(polls, collapse_firm = TRUE){

  pp <- polls %>%
    dplyr::select(id, pollingfirm, n, party, percent) %>%
    dplyr::group_by(id, pollingfirm, n) %>%
    dplyr::mutate(percent = percent / sum(percent) * 100) %>%
    dplyr::mutate(nn = n * (percent / 100),
                  nn = round_preserve_sum(nn)) %>%
    dplyr::ungroup() %>%
    dplyr::select(-percent) %>%
    tidyr::spread(party, nn) %>%
    dplyr::select(-id)

  if(collapse_firm){
    pp <- pp %>%
      dplyr::group_by(pollingfirm) %>%
      dplyr::summarise_all(mean)
  }

  pp <- pp %>%
    dplyr::select(-pollingfirm) %>%
    dplyr::summarise_all(sum) %>%
    tidyr::gather(party, nn, -n) %>%
    dplyr::mutate(percent = nn / n,
                  uncertainty = purrr::map2_dbl(percent, n, calc_uncertainty),
                  percent = percent * 100,
                  uncertainty = uncertainty * 100) %>%
    dplyr::select(-nn) %>%
    dplyr::select(pred = percent, error = uncertainty, party)

  return(pp)
}



