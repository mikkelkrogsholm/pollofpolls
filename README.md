
<!-- README.md is generated from README.Rmd. Please edit that file -->
pollofpolls
===========

The goal of pollofpolls is to make it easy to make a poll of polls.

This package is open sourced and all contributions are welcome. I have made some methological choices in this implementation that you are more than welcome to challenge.

Please do so by raising issues here on github and / or by creating new functions and doing a pull request.

In the code of each function I have tried to document my choices as good as possible. Please raise an issue if you feel something is wrong or missing.

Installation
------------

You can install pollofpolls from github with:

``` r
# install.packages("devtools")
devtools::install_github("mikkelkrogsholm/pollofpolls")
```

Example one: Driverless poll of polls
-------------------------------------

This is hands free driverless poll of polls calculation.

``` r

library(pollofpolls)

pollofpoll <- suppressMessages(pp_auto_poll_of_poll()) 

# Round the digits so it looks pretty
pollofpoll[, 1:2] <- purrr::map(pollofpoll[, 1:2], round, 2)

# Make a better looking table
knitr::kable(pollofpoll)
```

|   pred|  error| party |
|------:|------:|:------|
|  25.88|   0.77| a     |
|   5.24|   0.60| aa    |
|   5.91|   0.64| b     |
|   4.05|   0.26| c     |
|   2.21|   0.48| d     |
|   5.23|   0.65| f     |
|   4.86|   0.40| i     |
|   0.76|   0.12| k     |
|  17.83|   1.13| o     |
|   9.00|   0.16| oe    |
|  19.02|   0.54| v     |

Example two: Run down of each function
--------------------------------------

This is basically a run through of each part of the driverless poll of polls.

``` r
library(pollofpolls)

# Download the raw polls
raw_polls <- pp_get_raw_polls()

# Do a check on the polls
checked_polls <- pp_check_raw_polls(raw_polls = raw_polls, silent = TRUE)

# Calculate the pollster rating
pollster_rating <- pp_calc_pollster_rating()

# Add weights to the polls
polls_with_wt <- pp_add_weights(checked_polls = checked_polls, 
                                pollster_rating = pollster_rating)

# Calculate the final pole
final_poll <- pp_calc_poll(polls_with_wt = polls_with_wt)

# Round the digits so it looks pretty
final_poll[, 1:2] <- purrr::map(final_poll[, 1:2], round, 2)

# Make a better looking table
knitr::kable(final_poll)
```

|   pred|  error| party |
|------:|------:|:------|
|  25.88|   0.77| a     |
|   5.24|   0.60| aa    |
|   5.91|   0.64| b     |
|   4.05|   0.26| c     |
|   2.21|   0.48| d     |
|   5.23|   0.65| f     |
|   4.86|   0.40| i     |
|   0.76|   0.12| k     |
|  17.83|   1.13| o     |
|   9.00|   0.16| oe    |
|  19.02|   0.54| v     |
