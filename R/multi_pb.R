count_lines = function(f) {
  system(paste0("grep -Pv '^\\#' ", f, " | wc -l"), intern = TRUE) |> as.numeric()
}

# TODO: yellow, data, example model, readme, gif, post

find_csvs = function(td) {
  list.files(td, pattern = 'csv',
             full.names = TRUE) |>
    grep("-[1-4]-", x = _, value = TRUE)
}

#' Multiple progress bars
#' @description
#' Show multiple concurrent progress bars while fitting a model with `cmdstanr`
#'
#' @param m a CmdStanModel object
#' @param data_list a list of data to feed to \link[cmdstanr]{sample}
#' @export
multi_pb = function(m, data_list) {
  # Check if ... contains forbidden arguments TODO
  # Check if there are any pre-existing csv files TODO

  strt = Sys.time()

  td = tempdir()

  pre_existing_csvs = find_csvs(td)

  mir = mirai::mirai({m$sample(data_list,
                               parallel_chains = 4,
                               output_dir = td,
                               save_warmup = TRUE)},
                     m = m, data_list = data_list,
                     td = td)

  csv_files = 1

  while (length(csv_files) < 4) {
    # Watch the output directory until the CSV files show up

    Sys.sleep(.5)

    # TODO: 1) Get the model name from m$model_name()

    csv_files = find_csvs(td) |>
      sort()

    if (length(pre_existing_csvs) > 0) {
      csv_files = csv_files |>
        stringr::str_subset(paste0(pre_existing_csvs, collapse = "|"), negate = TRUE)
    }
  }

  header_info = readLines(csv_files[1], n = 40) # Will ns & nw always be within the first 40 lines?

  ns = grep("num_samples", header_info, value = TRUE) |>
    stringr::str_extract('[0-9]+') |>
    as.numeric()

  nw = grep("num_warmup", header_info, value = TRUE) |>
    stringr::str_extract('[0-9]+') |>
    as.numeric()

  message("num_samples: ", ns)

  message("num_warmup: ", nw)
  cat("Chain 1:\n\n")
  cat("Chain 2:\n\n")
  cat("Chain 3:\n\n")
  cat("Chain 4:\n\n")

  pb1 = utils::txtProgressBar(char = "■",
                              max = ns+nw,
                              width = 60,
                              style = 3)

  pb2 = utils::txtProgressBar(char = "■",
                              max = ns+nw,
                              width = 60,
                              style = 3)

  pb3 = utils::txtProgressBar(char = "■",
                              max = ns+nw,
                              width = 60,
                              style = 3)

  pb4 = utils::txtProgressBar(char = "■",
                              max = ns+nw,
                              width = 60,
                              style = 3)

  all_done = FALSE
  chain_counts = 0

  check_counter = 0
  rem_msg = ""

  while (!all_done && mirai::unresolved(mir)) {
    check_counter = check_counter + 1
    Sys.sleep(.5)

    # No clue where cmdstan stores the progress info, just grep the output

    chain_counts = sapply(csv_files, count_lines) - 1

    # setTxtProgressBar(pb1, chain_counts[1])
    # setTxtProgressBar(pb1, chain_counts[2])
    # setTxtProgressBar(pb1, chain_counts[3])
    # setTxtProgressBar(pb1, chain_counts[4])
    # https://stackoverflow.com/a/49232576

    cat("\033[7A")
    utils::setTxtProgressBar(pb1, chain_counts[1])
    cat("\033[2B")
    utils::setTxtProgressBar(pb2, chain_counts[2])
    cat("\033[2B")
    utils::setTxtProgressBar(pb3, chain_counts[3])
    cat("\033[2B")
    utils::setTxtProgressBar(pb4, chain_counts[4])
    cat("\033[1E")


    if (check_counter > 6 && (check_counter %% 2) == 0) {
      lowest_prop = min(chain_counts) / (ns+nw)
      cur_time = Sys.time()
      dt = (cur_time - strt)

      rem = 1 - lowest_prop

      rate = lowest_prop/as.numeric(dt)

      t_rem = rem / rate


      rem_msg = paste0("ETA of slowest chain: ", round(t_rem,digits=1), " ", attr(dt, "units"))

    } else {
      rem_msg = rem_msg
    }

    cat("\033[2K")
    cat(rem_msg)

    all_done = all(chain_counts == (ns+nw))
  }

  # One final set so they all show 100%
  cat("\033[7A")
  utils::setTxtProgressBar(pb1, chain_counts[1])
  cat("\033[2B")
  utils::setTxtProgressBar(pb2, chain_counts[2])
  cat("\033[2B")
  utils::setTxtProgressBar(pb3, chain_counts[3])
  cat("\033[2B")
  utils::setTxtProgressBar(pb4, chain_counts[4])
  cat("\033[1E")
  cat("\033[2K")

  close(pb1)
  close(pb2)
  close(pb3)
  close(pb4)

  mir[]
}

# library(mirai)
# library(cmdstanr)
# library(fastverse)
# library(ggplot2)
#
# freq = fread("~/gptools/data/tachve.csv", skip = 1) |> qM()
#
# padding = 10
# nr = nrow(freq)
# nc = ncol(freq)
#
# pr = nr + padding
# pc = nc + padding
#
# padded = matrix(0, pr, pc)
# padded[1:nr,1:nc] = freq
#
# # train mask --------------------------------------------------------------
#
# train_frac = .8
#
# msk = runif(length(freq)) > train_frac
#
# masked = freq
# masked[msk] = -1
#
# data_list = list(num_rows = nr,
#                  num_rows_padded = pr,
#                  num_cols = nc,
#                  num_cols_padded = pc,
#                  frequency = masked)
#
#
# data_list$n_unmasked = sum(masked != -1)
# data_list$not_masked = which(t(masked) != -1)
# data_list$y = t(masked)[data_list$not_masked]
#
# m = cmdstan_model(stan_file = "~/projects/multipb/stan/trees_mod.stan", include_paths = "~/gptools/stan/gptools/stan/")
#
# res = multi_pb(m, data_list)
