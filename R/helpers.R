#' Rounds but preserves sum
#'
#' @param x numbers to round
#' @param digits digits to keep
#'
#' @return a vector
#'
#' @examples
#' x <- rep(10 / 3, 3)
#' round_preserve_sum(x)
round_preserve_sum <- function(x, digits = 0) {
  up <- 10 ^ digits
  x <- x * up
  y <- floor(x)
  indices <- tail(order(x-y), round(sum(x)) - sum(y))
  y[indices] <- y[indices] + 1
  y / up
}

#' Calculate poll uncertainty
#'
#' Uses a formula to calculate poll uncertainty
#'
#' @param p share of poll
#' @param n number of respondents
#' @param z the z-score
#'
#' @return a number
#'
#' @examples
#' calc_uncertainty(.2, 1000)
calc_uncertainty <- function(p, n, z = 1.96){

  if(p > 1) {
    warning("p must be between 0 - 1")
  }

  out <- z * sqrt((p * (1-p)) / n)

  return(out)

}
