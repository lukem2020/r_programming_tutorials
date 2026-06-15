# S10 Time-to-event analysis (TLG KMG01 plot + TTET01 summary).

# Kaplan-Meier by arm for configured ADTTE PARAMCDs and top TEAE preferred terms.



suppressPackageStartupMessages({

  library(dplyr)

  library(ggplot2)

  library(survival)

})



pt_endpoint_id <- function(aedecod) paste0("PT|", aedecod)



pt_from_endpoint_id <- function(endpoint_id) sub("^PT\\|", "", endpoint_id)



is_pt_endpoint <- function(endpoint_id) grepl("^PT\\|", endpoint_id)



tte_endpoint_cfg <- function(cfg, paramcd) {

  eps <- cfg$time_to_event_endpoints

  hit <- Filter(function(e) identical(e$paramcd, paramcd), eps)

  if (length(hit) == 0L) eps[[1]] else hit[[1]]

}



tte_endpoint_choices <- function(cfg) {

  eps <- cfg$time_to_event_endpoints

  stats::setNames(

    vapply(eps, function(e) e$paramcd, character(1)),

    vapply(eps, function(e) e$label, character(1))

  )

}



tte_all_endpoint_choices <- function(cfg, adae, adsl, arms = NULL) {

  fixed <- tte_endpoint_choices(cfg)

  top_pts <- teae_top_terms(adae, adsl, cfg, arms = arms)

  if (length(top_pts) == 0L) return(fixed)

  pt_choices <- stats::setNames(

    vapply(top_pts, pt_endpoint_id, character(1)),

    paste0("TEAE: ", top_pts)

  )

  c(fixed, pt_choices)

}



tte_endpoint_meta <- function(cfg, endpoint_id) {

  if (is_pt_endpoint(endpoint_id)) {

    pt <- pt_from_endpoint_id(endpoint_id)

    list(

      label = pt,

      event_label = sprintf("first occurrence of %s (TRTEMFL = 'Y')", pt),

      censor_label = "last dose + 1 day"

    )

  } else {

    ep <- tte_endpoint_cfg(cfg, endpoint_id)

    list(

      label = ep$label,

      event_label = ep$event_label,

      censor_label = ep$censor_label

    )

  }

}



.tte_data <- function(adtte, cfg, paramcd) {

  adtte %>%

    filter(.data$PARAMCD == paramcd) %>%

    mutate(ARM = factor(.data$ARM, levels = arm_levels(cfg)),

           event = 1L - .data$CNSR) %>%

    filter(!is.na(.data$ARM))

}



derive_pt_tte <- function(adsl, adae, cfg, aedecod, arms = NULL) {

  sl <- safety_adsl(adsl, cfg) %>%

    filter_by_arms(., cfg, arms) %>%

    mutate(

      cens_days = dplyr::coalesce(

        as.numeric(.data$TRTDURD),

        as.numeric(.data$TRTEDT - .data$TRTSDT) + 1

      )

    )



  first_events <- adae %>%

    filter(

      .data$TRTEMFL == "Y",

      .data$AEDECOD == aedecod,

      .data$USUBJID %in% sl$USUBJID

    ) %>%

    group_by(.data$USUBJID) %>%

    summarise(first_day = max(min(.data$ASTDY, na.rm = TRUE), 1), .groups = "drop")



  sl %>%

    left_join(first_events, by = "USUBJID") %>%

    mutate(

      PARAMCD = pt_endpoint_id(aedecod),

      CNSR = ifelse(is.na(.data$first_day), 1L, 0L),

      AVAL = ifelse(is.na(.data$first_day), .data$cens_days, .data$first_day),

      ARM = factor(.data$ARM, levels = arm_levels(cfg)),

      event = 1L - .data$CNSR

    ) %>%

    filter(!is.na(.data$AVAL), .data$AVAL > 0, !is.na(.data$ARM))

}



resolve_tte_data <- function(adtte, adsl, adae, cfg, endpoint_id, arms = NULL) {

  if (is_pt_endpoint(endpoint_id)) {

    derive_pt_tte(adsl, adae, cfg, pt_from_endpoint_id(endpoint_id), arms)

  } else {

    .tte_data(adtte, cfg, endpoint_id)

  }

}



km_fit <- function(adtte, cfg, endpoint_id, adsl = NULL, adae = NULL, arms = NULL) {

  d <- resolve_tte_data(adtte, adsl, adae, cfg, endpoint_id, arms)

  survival::survfit(survival::Surv(AVAL, event) ~ ARM, data = d)

}



km_logrank_p <- function(adtte, cfg, endpoint_id, adsl = NULL, adae = NULL, arms = NULL) {

  d <- resolve_tte_data(adtte, adsl, adae, cfg, endpoint_id, arms)

  sd <- survival::survdiff(survival::Surv(AVAL, event) ~ ARM, data = d)

  stats::pchisq(sd$chisq, df = length(sd$n) - 1, lower.tail = FALSE)

}



.km_steps <- function(fit, cfg) {

  strata <- rep(names(fit$strata), fit$strata)

  arm <- sub("^ARM=", "", strata)

  df <- data.frame(time = fit$time, surv = fit$surv, n.censor = fit$n.censor,

                   ARM = arm, stringsAsFactors = FALSE)

  starts <- data.frame(time = 0, surv = 1, n.censor = 0,

                       ARM = unique(arm), stringsAsFactors = FALSE)

  out <- bind_rows(starts, df)

  out$ARM <- factor(out$ARM, levels = arm_levels(cfg))

  out %>% arrange(.data$ARM, .data$time)

}



km_plot <- function(adtte, cfg, endpoint_id, adsl = NULL, adae = NULL, arms = NULL) {

  ep <- tte_endpoint_meta(cfg, endpoint_id)

  fit <- km_fit(adtte, cfg, endpoint_id, adsl, adae, arms)

  steps <- .km_steps(fit, cfg)

  cens <- steps %>% filter(.data$n.censor > 0)

  p_val <- km_logrank_p(adtte, cfg, endpoint_id, adsl, adae, arms)

  p_lab <- ifelse(p_val < 0.001, "Log-rank p < 0.001",

                  sprintf("Log-rank p = %.3f", p_val))

  title_prefix <- if (is_pt_endpoint(endpoint_id)) {

    sprintf("Time to first %s by arm", tolower(ep$label))

  } else {

    paste0("Time to first ", tolower(ep$label), " by arm")

  }



  ggplot(steps, aes(x = .data$time, y = .data$surv, colour = .data$ARM)) +

    geom_step(linewidth = 0.9) +

    geom_point(data = cens, shape = 3, size = 2.2, show.legend = FALSE) +

    scale_colour_manual(values = arm_palette(cfg)) +

    scale_y_continuous(limits = c(0, 1), labels = scales::percent) +

    labs(

      title = title_prefix,

      subtitle = paste0("Kaplan-Meier (event-free survival) \u2013 KMG01 | ", p_lab),

      x = "Days since first dose",

      y = paste0("Probability free of ", tolower(ep$label)),

      colour = "Arm",

      caption = paste0("Event = ", ep$event_label, "; + = censored at ", ep$censor_label)

    ) +

    theme_clinical()

}



km_median_table <- function(adtte, cfg, endpoint_id, adsl = NULL, adae = NULL, arms = NULL) {

  fit <- km_fit(adtte, cfg, endpoint_id, adsl, adae, arms)

  s <- summary(fit)$table

  if (is.null(dim(s))) s <- t(as.matrix(s))

  arms_out <- sub("^ARM=", "", rownames(s))

  fmt <- function(x) ifelse(is.na(x) | !is.finite(x), "NE", as.character(round(x, 0)))

  data.frame(

    Arm = factor(arms_out, levels = arm_levels(cfg)),

    N = as.integer(s[, "records"]),

    Events = as.integer(s[, "events"]),

    `Median (days)` = fmt(s[, "median"]),

    `95% CI lower` = fmt(s[, "0.95LCL"]),

    `95% CI upper` = fmt(s[, "0.95UCL"]),

    check.names = FALSE,

    stringsAsFactors = FALSE

  ) %>% arrange(.data$Arm)

}


