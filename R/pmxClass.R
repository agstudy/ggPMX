
#' Create simulation object
#'
#' @param file \code{character} path to the simulation file
#' @param irun \code{character} name of the simulation column
#' @param idv \code{character} name of the ind. variable
#' @export

#' @example inst/examples/vpc.R
pmx_sim <- function(
                    file,
                    irun,
                    idv) {
  if (missing(idv)) idv <- "TIME"
  if (file.exists(file)) {
    sim <- pmx_fread(file)
    if (tolower(idv) == "time") {
      idvn <- names(sim)[tolower(names(sim)) == "time"]
      setnames(sim, idvn, "TIME")
      idv <- "TIME"
    }
    id_col <- grep("^id$", names(sim), ignore.case = TRUE, value = TRUE)
    setnames(sim, id_col, "ID")
    obj <- list(
      sim = sim,
      idv = idv,
      irun = irun
    )
    structure(obj, class = c("pmxSimClass", "list"))
  }
}



check_argument <- function(value, pmxname) {
  call <- match.call()
  if (any(missing(value) | is.null(value))) {
    stop(
      sprintf(
        "Please set a %s argument",
        deparse(call$value), pmxname
      )
    )
  }
  value
}


#' Create a pmx object
#'
#' Create a pmx object from a data source
#' @param config Can be either :
#' The complete path for the configuration file, the name of configuration within the built-in
#' list of configurations, or a configuration object.
#' @param sys the system name can be MLX/NM
#' @param directory \code{character} modelling output directory.
#' @param input \code{character} complete path to the modelling input file
#' @param dv \code{character} the name of measurable variable used in the input modelling file
#' @param dvid \emph{[Optional]} \code{character} observation type parameter. This is mandatory
#' in case of multiple endpoint (PKPD).
#' @param cats \emph{[Optional]}\code{character} vector of categorical covariates
#' @param conts \emph{[Optional]}\code{character} vector of continuous covariates
#' @param occ \emph{[Optional]}\code{character} occasional covariate variable name
#' @param strats \emph{[Optional]}\code{character} extra stratification variables
#' @param settings \emph{[Optional]}\code{pmxSettingsClass} \code{\link{pmx_settings}}
#' shared between all plots
#' @param endpoint \code{pmxEndpointClass} or \code{integer} or \code{charcater} defalut to NULL
#' of the endpoint code.   \code{\link{pmx_endpoint}}
#' @param sim \code{pmxSimClass} default to NULL. \code{\link{pmx_sim}}
#' @param bloq \code{pmxBLOQClass} default to NULL. \code{\link{pmx_bloq}}
#' @return \code{pmxClass} controller object.

#' @export
#' @example inst/examples/controller.R
pmx <-
  function(config, sys=c("mlx", "nm"), directory, input, dv, dvid, cats=NULL, conts=NULL, occ=NULL, strats=NULL,
           settings=NULL, endpoint=NULL, sim=NULL, bloq=NULL) {
    directory <- check_argument(directory, "work_dir")
    input <- check_argument(input, "input")
    dv <- check_argument(dv, "dv")
    ## dvid <- check_argument(dvid, "dvid")
    if (missing(cats)) cats <- ""
    if (missing(sim)) sim <- NULL
    if (missing(endpoint)) {
      endpoint <- NULL
    }
    assert_that(is_character_or_null(cats))
    if (missing(conts)) conts <- ""
    assert_that(is_character_or_null(conts))
    if (missing(occ)) occ <- ""
    assert_that(is_character_or_null(occ))
    if (missing(strats)) strats <- ""
    assert_that(is_character_or_null(strats))

    if (!inherits(config, "pmxConfig")) {
      if ("populationParameters.txt" %in% list.files(directory)) sys <- "mlx18"
      config <- load_config(config, sys)
    }
    if (missing(settings)) settings <- pmx_settings()
    if (!inherits(settings, "pmxSettingsClass")) {
      settings <- pmx_settings()
    }
    if (missing(bloq)) bloq <- NULL
    assert_that(inherits(bloq, "pmxBLOQClass") || is.null(bloq))

    pmxClass$new(directory, input, dv, config, dvid, cats, conts, occ, strats, settings, endpoint, sim, bloq)
  }


#' @rdname pmx
#' @details
#' \code{pmx_mlx}  is a wrapper to mlx for the MONOLIX system ( \code{sys="mlx"})
#' @export
pmx_mlx <-
  function(config, directory, input, dv, dvid, cats, conts, occ, strats, settings, endpoint, sim, bloq) {
    pmx(config, "mlx", directory, input, dv, dvid, cats, conts, occ, strats, settings, endpoint, sim, bloq)
  }



#' Create a controller from mlxtran file
#'
#' @param file_name \code{character} mlxtran file path.
#' @param call \code{logical} if TRUE the result is the parameters parsed
#' @param ... extra arguments passed to pmx_mlx.
#' @rdname pmx
#'
#' @export
#' @details
#'
#' \code{pmx_mlxtran} parses mlxtran file and guess \code{\link{pmx_mlx}} arguments. In case of
#' multi endpoint the first endpoint is selected. You can though set the endpoint through the same argument.
#' When you set \code{call=TRUE},no controller is created but only the parameters parsed
#' by mlxtran. This can be very helpful, in case you would like to customize parameters
#' (adding settings vi pmx_settings, chnag eth edefault endpoint.)

pmx_mlxtran <- function(file_name, config="standing", call=FALSE, endpoint, ...) {
  params <- parse_mlxtran(file_name)
  params$config <- config
  rr <- as.list(match.call()[-1])
  rr$file_name <- NULL
  params <- append(params, rr)
  if (!missing(endpoint)) {
    params$endpoint <- NULL
    params$endpoint <- endpoint
  }


  if (call) {
    params$call <- NULL
    return(params)
  }

  params$call <- NULL

  do.call(pmx_mlx, params)
}

formula_to_text <- function(form) {
  if (is.formula(form)) {
    paste(as.character(as.list(form)[-1]), collapse = " and ")
  } else {
    form
  }
}

#' Create controller global settings
#' @param is.draft \code{logical} if FALSE any plot is without draft annotation
#' @param use.abbrev \code{logical} if TRUE use abbreviations mapping for axis names
#' @param color.scales \code{list} list containing elements of scale_color_manual
#' @param use.labels \code{logical} if TRUE replace factor named by cats.labels
#' @param cats.labels \code{list} list of named vectors for each factor
#' @param use.titles \code{logical} FALSE to generate plots without titles
#' @param effects \code{list} list of effects levels and labels
#' @param ... extra parameter not used yet
#' @return pmxSettingsClass object
#' @example inst/examples/pmx-settings.R
#' @export
pmx_settings <-
  function(is.draft=TRUE, use.abbrev=FALSE, color.scales=NULL,
           cats.labels=NULL, use.labels=FALSE, use.titles=TRUE,
           effects=NULL,
           ...) {
    if (!missing(effects) && !is.null(effects)) {
      if (!is.list(effects)) stop("effects should be a list")

      if (!exists("levels", effects) || !exists("labels", effects)) {
        stop("effects should be a list that contains levels and labels")
      }
      if (length(effects$labels) != length(effects$levels)) {
        stop("effects should be a list that contains levels and labels have the same length")
      }
    }

    res <- list(
      is.draft = is.draft,
      use.abbrev = use.abbrev,
      color.scales = color.scales,
      use.labels = use.labels,
      cats.labels = cats.labels,
      use.titles = use.titles,
      effects = effects
    )
    if (use.labels) {
      res$labeller <- do.call("labeller", cats.labels)
    }

    structure(
      res, ...,
      class = "pmxSettingsClass"
    )
  }




#' Creates pmx endpoint object
#'
#' @param code \code{character} endpoint code : used to filter observations DVID==code.
#' @param label \code{character} endpoint label: used to set title and axis labels
#' @param unit  \code{character} endpoint unit : used to set title and axis labels
#' @param file.code \code{character} endpoint file code : used to set predictions and finegrid \cr
#' files extensions in case using code parameter is not enough.
#' @param trans  \code{list} Transformation parameter not used yet.
#' @export
#'
#' @example inst/examples/endpoint.R
#' @details
#' In case of multiple endpoints, pkpd case for example, we need to pass endpoint to the pmx call.
#' Internally , ggPMX will filter the observations data set to keep only rows satisfying \code{DVID==code}.
#' The \code{code} is also used to find the right predictions and or fingrid files.
#' ggPMX use the configuration file to fine the path of the predictions file
#' (like the single endpoint case) and then filter the right file using the code parameter. \cr
#' For example:
#' \itemize{
#' \item predictions\{code\}.txt for mlx16
#' \item predictions\{code\}.txt  and y\{code\}_residual for mlx18
#' }
#'
#' For some tricky examples the code parameter is not enough to find the files. In that case the
#' \code{file.code} parameter is used to distinguish the endpoint files.

pmx_endpoint <-
  function(code,
           label="",
           unit="",
           file.code=code,
           trans =NULL) {
    assert_that(is.character(code))
    assert_that(is.character(file.code))
    assert_that(is.character(unit))
    assert_that(is.character(label))
    assert_that(is_character_or_null(trans))
    res <- list(
      code = code,
      label = label,
      unit = unit,
      file.code = file.code,
      trans = trans
    )

    structure(
      res,
      class = "pmxEndpointClass"
    )
  }



#' Creates BLOQ object attributes
#'
#' @param cens \code{character} the censoring column name
#' @param limit \code{character}  the limit column name (optional)
#' @param colour \code{character}  the color of the geom
#' @param size \code{numeric}  the size of the geom
#' @param alpha  \code{numeric}  the alpha of the geom
#' @param show \code{logical} if FALSE remove all censory observations
#' @param ... any other graphical parameter
#'
#' @export
#' @details
#' To define that a measurement is censored, the observation data set should include
#' a CENSORING column ( default to `CENS` ) and put 1 for lower limit or -1 for upper limit. \cr
#' Optionally, data set can contain have a limit column ( default to `LIMIT`) column to set the other limit.

pmx_bloq <-
  function(
           cens="CENS",
           limit ="LIMIT",
           colour="pink",
           size=2,
           alpha=0.9,
           show=TRUE,
           ...) {
    res <- list(
      cens = cens,
      limit = limit,
      show = show,
      colour = colour,
      size = size,
      alpha = alpha,
      ...
    )

    structure(
      res,
      class = "pmxBLOQClass"
    )
  }




#' Create a new plot  of the desired type
#'
#' @param ctr \code{pmxClass} controller object
#' @param ptype plot type can be:
##' \itemize{
##'  \item{"IND"}{ Individual plot type: \code{\link{individual}} }
##'  \item{"DIS"}{ Distribution plot type : \code{\link{distrib}}}
##'  \item{"SCATTER"}{ Residual plot type :\code{\link{residual}}}
##' }
##' @param pname plot name, if missing it will be created using function aestetics
##' @param filter optional filter which will be applied to plotting data
##' @param strat.facet \code{formula} define categorical stratification as formula
##' @param strat.color \code{character}
##' @param trans \code{list}{transformation operator}
##' @param color.scales \code{list} can be used with strat.color to set scale_color_manual
##' @param use.defaults \code{logical} if FALSE do not use defaults defined in yaml init files
#' @param ... other plot parameters to configure \code{\link{pmx_gpar}}.
#'
#' @family pmxclass
#' @return invisible ctr object
#' @export
set_plot <- function(
                     ctr,
                     ptype = c(
                       "IND", "DIS", "SCATTER", "ETA_PAIRS",
                       "ETA_COV", "PMX_QQ", "VPC", "PMX_DENS"
                     ),
                     pname,
                     use.defaults=TRUE,
                     filter =NULL,
                     strat.color=NULL,
                     strat.facet=NULL,
                     color.scales=NULL,
                     trans=NULL, ...) {
  assert_that(is_pmxclass(ctr))
  ptype <- match.arg(ptype)
  assert_that(is_string_or_null(pname))
  assert_that(is_string_or_null(strat.color))
  assert_that(is_string_or_formula_or_null(strat.facet))



  params <- list(...)

  if (use.defaults) {
    defaults_yaml <-
      file.path(system.file(package = "ggPMX"), "init", "defaults.yaml")
    defaults <- yaml.load_file(defaults_yaml)
    names(defaults) <- tolower(names(defaults))
    def <- if (tolower(ptype) %in% names(defaults)) {
      defaults[[tolower(ptype)]]
    } else {
      if (ptype == "DIS") {
        if (params$type == "hist") {
          defaults[["dis_hist"]]
        } else {
          defaults[["dis_box"]]
        }
      }
    }
    if (!is.null(def)) {
      params <- l_left_join(def, params)
      params$ptype <- NULL
    }
  }
  if (ptype == "VPC") {
    params$dv <- ctr$sim$dv
    params$idv <- ctr$sim$idv
  }
  conf <-
    switch(ptype,
      IND = do.call(individual, params),
      DIS = if (ctr$has_re) do.call(distrib, params),
      SCATTER = do.call(residual, params),
      ETA_PAIRS = if (ctr$has_re) do.call(eta_pairs, params),
      ETA_COV = if (ctr$has_re) do.call(eta_cov, params),
      PMX_QQ = do.call(pmx_qq, params),
      PMX_DENS = do.call(pmx_dens, params),
      VPC = do.call(pmx_vpc, params)
    )
  if (!is.null(substitute(filter))) {
    filter <- deparse(substitute(filter))
    filter <- local_filter(filter)
  }
  if (!is.null(conf)) {
    conf[["filter"]] <- filter
    conf[["trans"]] <- trans
    if (!is.null(strat.color)) conf[["strat.color"]] <- strat.color
    if (!is.null(strat.facet)) conf[["strat.facet"]] <- strat.facet
    if (!is.null(color.scales)) conf$gp[["color.scales"]] <- color.scales
    ctr[["config"]][["plots"]][[toupper(pname)]] <-
      c(ptype = ptype, list(...))
    ctr$add_plot(conf, pname)
  }
  invisible(ctr)
}

#' update or add a new abbreviation
#'
#' @param ctr  \code{pmxClass} controller object
#' @param ... Options to set or add, with the form \code{name = value}.
#' @export
#' @examples
#' ctr <- theophylline()
#' ctr %>% set_abbrev("new_param"="new value")
#' ctr %>% get_abbrev("new_param")


set_abbrev <- function(ctr, ...) {
  assert_that(is_pmxclass(ctr))
  abbrev <- if (length(ctr$abbrev) > 0) {
    l_left_join(ctr$abbrev, list(...))
  } else {
    unlist(list(...), recursive = FALSE)
  }
  class(abbrev) <- c("abbreviation", "list")
  ctr$abbrev <- abbrev
}

#' S3 print abbreviation
#' @param x object of class configs
#' @param ... pass additional options (not used presently)
#' @return print abbreviation
#' @export
print.abbreviation <- function(x, ...) {
  assert_that(inherits(x, "abbreviation"))
  for (i in seq_len(length(x)))
    cat(sprintf("%s : %s \n", names(x)[i], x[[i]]))
}

#' Get abbreviation definition by key
#'
#' @param param abbreviation term
#' @param ctr \code{pmxClass} controller
#'
#' @return \code{character} abbreviation definition
#' @export

get_abbrev <- function(ctr, param) {
  keys <- ctr$abbrev
  if (missing(param)) {
    keys
  } else {
    if (!is.null(keys[[param]])) keys[[param]] else param
  }
}


#' Get plot object
#'
#' @param ctr  \code{pmxClass} controller object
#' @param nplot character the plot name
#' @param npage integer or integer vector, set page number in case of multi pages plot
#'
#' @family pmxclass
#' @return ggplot object
#' @export
#' @examples
#' \dontrun{
#' library(ggPMX)
#' ctr <- theophylline()
#' p1 <- ctr %>% get_plot("iwres_ipred")
#' ## get all pages or some pages
#' p2 <- ctr %>% get_plot("individual")
#' ## returns one page of individual plot
#' p2 <- ctr %>% get_plot("individual",npage=1)
#' p3 <- ctr %>% get_plot("individual",npage=c(1,3))
#' ## get distribution plot
#' pdistri <- ctr %>% get_plot("eta_hist")
#'
#' }

get_plot <- function(ctr, nplot, npage = NULL) {
  if (is.numeric(npage)) {
    npage <- as.integer(npage)
  }
  assert_that(is_pmxclass(ctr))
  assert_that(is_string(nplot))
  assert_that(is_integer_or_null(npage))
  nplot <- tolower(nplot)
  assert_that(is_valid_plot_name(nplot, plot_names(ctr)))
  xx <- ctr$get_plot(nplot)

  if (is.function(xx)) {
    xx(npage)
  } else {
    xx
  }
}



#' Get plot names
#'
#' @param ctr  \code{pmxClass} controller object
#'
#' @family pmxclass
#' @return list of plot names
#' @export

plot_names <- function(ctr) {
  assert_that(is_pmxclass(ctr))
  ctr$plots()
}

#' Get plots description
#'
#' @param ctr  \code{pmxClass} controller object
#'
#' @family pmxclass
#' @return data.frame of plots
#' @export

plots <- function(ctr) {
  existsF <- function(...) do.call("existsFunction", list(...))
  assert_that(is_pmxclass(ctr))
  x <- ctr$config
  function_name <- function(nn) {
    fn <- sprintf("pmx_plot_%s", nn)
    if (!existsF(fn, where = asNamespace("ggPMX"))) {
      fn <- sprintf("pmx_plot('%s',...)", nn)
    }
    fn
  }
  if (exists("plots", x)) {
    pp <- x$plots
    names(pp) <- tolower(names(pp))
    pp <- pp[ctr$plots()]
    data.table(
      plot_name = names(pp),
      plot_type = sapply(pp, "[[", "ptype"),
      plot_function = sapply(names(pp), function_name)
    )
  }
}





#' Get the plot config by name
#'
#' @param ctr the controller object
#' @param pname the plot name
#'
#' @family pmxclass
#' @return the config object
#' @export
#'
#' @examples
#' \dontrun{
#' ctr <- theophylline()
#' ctr %>% set_plot("IND", pname = "indiv1")
#' ctr %>% get_plot_config("distr1")
#' }
get_plot_config <- function(ctr, pname) {
  assert_that(is_pmxclass(ctr))
  ctr$get_config(pname)
}


#' Get controller data set
#'
#' @param ctr the controller object
#' @param data_set the data set name
#'
#' @family pmxclass
#' @return a data.table of the named data set if available.
#' @export
get_data <- function(ctr, data_set = c(
                     "estimates", "predictions",
                     "eta", "finegrid", "input", "sim",
                     "individual"
                   )) {
  assert_that(is_pmxclass(ctr))
  ## data_set <- match.arg(data_set)
  if (data_set == "individual") data_set <- "IND"
  if (data_set == "input") {
    copy(ctr[["input"]])
  } else {
    copy(ctr[["data"]][[data_set]])
  }
}

#' Set a controller data set
#'
#' @param ctr the controller object
#' @param ... a named  list parameters (see example)
#' @family pmxclass
#' @details
#' This function can be used to set an existing data set or to create a new one. The basic
#' idea is to change the  built-in data set (change the factor level names, change some rows
#' values or apply any other data set operation) and use the new data set using the dname
#' parameter of pmx_plot family functions.
#' @examples
#' ctr <- theophylline()
#' dx <- ctr %>% get_data("eta")
#' dx <- dx[,EFFECT:=factor(
#'         EFFECT,levels=c("ka", "V", "Cl"),
#'         labels=c("Concentration","Volume","Clearance"))]
#' ## update existing data set
#' ctr %>% set_data(eta=dx)
#' ## or create a new data set
#' ctr %>% set_data(eta_long=dx)
#' @export
set_data <- function(ctr, ...) {
  assert_that(is_pmxclass(ctr))
  params <- as.list(match.call(expand.dots = TRUE))[-c(1, 2)]
  if (!nzchar(names(params))) {
    stop("each data set should be well named")
  }
  invisible(Map(function(n, v) ctr$data[[n]] <- eval(v), names(params), params))
}

#' Get category covariates
#'
#' @param ctr the controller object
#'
#' @family pmxclass
#' @return a charcater vector
#' @export
get_cats <- function(ctr) {
  assert_that(is_pmxclass(ctr))
  ctr$cats
}


#' Get extra stratification variables
#'
#' @param ctr the controller object
#'
#' @family pmxclass
#' @return a charcater vector
#' @export
get_strats <- function(ctr) {
  assert_that(is_pmxclass(ctr))
  ctr$strats
}

#' Get covariates variables
#'
#' @param ctr the controller object
#'
#' @family pmxclass
#' @return a charcater vector
#' @export
get_covariates <- function(ctr) {
  assert_that(is_pmxclass(ctr))
  res <- unique(c(ctr$cats, ctr$conts))
  res[nzchar(res)]
}



#' Get continuous covariates
#'
#' @param ctr the controller object
#'
#' @family pmxclass
#' @return a charcater vector
#' @export
get_conts <- function(ctr) {
  assert_that(is_pmxclass(ctr))
  ctr$conts
}


#' Get controller occasional covariates
#'
#' @param ctr the controller object
#'
#' @family pmxclass
#' @return a charcater vector
#' @export
get_occ <- function(ctr) {
  assert_that(is_pmxclass(ctr))
  ctr$occ
}

# pmxSource (R6 Class) ------------------------------------------------------------
#' @importFrom R6 R6Class
pmxClass <- R6::R6Class(
  "pmxClass",

  # Private methods ------------------------------------------------------------
  private = list(
    .data_path = "",
    .input_path = "",
    .covariates = NULL,
    .plots = list(),
    .plots_configs = list()
  ),

  # Public methods -------------------------------------------------------------
  public = list(
    data = NULL,
    config = NULL,
    input = NULL, input_file = NULL,
    dv = NULL,
    dvid = NULL, cats = NULL, conts = NULL, occ = NULL,
    strats = NULL,
    settings = NULL,
    has_re = FALSE, re = NULL,
    abbrev = list(),
    endpoint = NULL,
    warnings = list(),
    footnote = FALSE,
    save_dir = NULL,
    report_queue = list(),
    report_n = 0,
    plot_file_name = "",
    sim = NULL,
    bloq = NULL,
    initialize = function(data_path, input, dv, config, dvid, cats, conts, occ, strats, settings, endpoint, sim, bloq)
      pmx_initialize(self, private, data_path, input, dv, config, dvid, cats, conts, occ, strats, settings, endpoint, sim, bloq),

    print = function(data_path, config, ...)
      pmx_print(self, private, ...),

    enqueue_plot = function(pname) {
      self$report_n <- self$report_n + 1
      pname_file <- paste0(pname, "-", self$report_n)
      self$plot_file_name <- pname_file
      self$report_queue <- c(self$report_queue, pname_file)
    },
    dequeue_plot = function() pmx_dequeue_plot(self),
    # Operations ---------------------------------------------------------------
    add_plot = function(x, pname)
      pmx_add_plot(self, private, x, pname),

    update_plot = function(pname, strat.facet=NULL, strat.color=NULL,
                           filter=NULL, trans=NULL,
                           ..., pmxgpar = NULL) {
      pmx_update_plot(
        self, private, pname,
        strat.color = strat.color, strat.facet = strat.facet,
        filter, trans, ..., pmxgpar = pmxgpar
      )
    },

    remove_plot = function(pname, ...)
      pmx_remove_plot(self, private, pname, ...),

    get_config = function(pname)
      pmx_get_config(self, private, pname),

    set_config = function(pname, new)
      pmx_set_config(self, private, pname, new),
    get_plot = function(pname)
      pmx_get_plot(self, private, pname),

    plots = function()
      pmx_plots(self, private),

    post_load = function()
      pmx_post_load(self, private)
  )
)

pmx_initialize <- function(self, private, data_path, input, dv,
                           config, dvid, cats, conts, occ, strats,
                           settings, endpoint, sim, bloq) {
  DVID <- NULL
  if (missing(data_path) || missing(data_path)) {
    stop(
      "Expecting source path(directory ) and a config path",
      call. = FALSE
    )
  }
  if (missing(dvid)) dvid <- NULL
  if (any(missing(occ) | is.null(occ) | is.na(occ))) occ <- ""
  if (any(missing(cats) | is.null(cats) | is.na(cats))) cats <- ""
  if (any(missing(conts) | is.null(conts) | is.na(conts))) conts <- ""
  if (any(missing(strats) | is.null(strats) | is.na(strats))) strats <- ""
  if (missing(settings)) settings <- NULL
  if (missing(bloq)) bloq <- NULL

  private$.data_path <- data_path
  self$save_dir <- data_path
  if (is.character(input)) {
    private$.input_path <- input
  }
  self$config <- config
  self$dv <- dv
  self$dvid <- dvid
  self$cats <- cats
  self$conts <- conts
  self$occ <- toupper(occ)
  self$strats <- strats
  self$settings <- settings
  self$bloq <- bloq

  if (!is.null(endpoint) && is.atomic(endpoint)) {
    endpoint <- pmx_endpoint(code = as.character(endpoint))
  }
  self$endpoint <- endpoint
  if (is.character(input) && file.exists(input)) {
    self$input_file <- input
    self$input <- read_input(input, self$dv, self$dvid, self$cats, self$conts, self$strats, self$occ, self$endpoint)
  } else {
    if (!inherits(input, "data.frame")) {
      stop("observation data should be either a file or a data.frame")
    }
    self$input <- setDT(input)
  }

  self$data <- load_source(
    sys = config$sys, private$.data_path,
    self$config$data, dvid = self$dvid,
    endpoint = self$endpoint,
    occ = self$occ
  )
  ##
  ## check random effect

  if (!is.null(self$data[["eta"]])) {
    re <- grep("^eta_(.*)_(mode|mean)", names(self$data[["eta"]]), value = TRUE)
    if (length(re) > 0) {
      self$has_re <- TRUE
      self$re <- gsub("^eta_(.*)_(mode|mean)", "\\1", re)
      self$data[["eta"]] <-
        post_load_eta(
          self$data[["eta"]],
          self$input, self$sys, self$occ
        )
    }
  }

  self$post_load()

  if (!is.null(sim)) {
    dx <- sim[["sim"]]
    inn <- copy(self$input)[, self$dv := NULL]
    # check for unique keys in the observation variables
    if (sum(duplicated(inn[, c("ID", "TIME"), with = FALSE])) > 0) {
      warning(
        paste(
          " Different covariates for the same patient same time point\n",
          "--> Duplicated created in the vpc data set."
        ),
        call. = FALSE
      )
    }

    self$data[["sim"]] <- merge(dx, inn, by = c("ID", "TIME"))


    self$sim <- sim
  }



  ## abbrev
  keys_file <- file.path(
    system.file(package = "ggPMX"), "init", "abbrev.yaml"
  )
  self$abbrev <- set_abbrev(self, yaml.load_file(keys_file))

  ## create all plots
  for (nn in names(self$config$plots)) {
    x <- self$config$plots[[nn]]
    x$pname <- tolower(nn)
    x$use.defaults <- FALSE
    do.call(set_plot, c(ctr = self, x))
  }
}
#' @importFrom knitr kable
pmx_print <- function(self, private, ...) {
  cat("\npmx object:\n")
  paste_col <- function(n, x) if (all(x != "")) c(n, paste(x, collapse = ","))
  ctr_table <-
    rbind(
      c(
        "working directory",
        basename(dirname(private$.data_path))
      ),
      c("Modelling input file", basename(private$.input_path)),
      c("dv", self$dv),
      c("dvid", self$dvid),
      paste_col("cats", self %>% get_cats()),
      paste_col("conts", self %>% get_conts()),
      paste_col("strats", self %>% get_strats())
    )
  colnames(ctr_table) <- c("PARAM", "VALUE")
  print(kable(ctr_table))
  print(self$config, ctr = self, plot_names = names(private$.plots))
}




pmx_transform <- function(x, dx, trans, direction) {
  if (is.character(trans)) {
    params <- strsplit(trans, "_")[[1]]
    trans <- params[1]
    direction <- params[2]
  }
  cols_res <- function(x) {
    with(x, {
      switch(
        direction,
        x = aess$x,
        y = aess$y,
        xy = c(aess$x, aess$y)
      )
    })
  }

  cols_ind <- function(x) {
    switch(
      direction,
      x = "TIME",
      y = c("PRED", "IPRED", "DV"),
      xy = c("TIME", "PRED", "IPRED", "DV")
    )
  }

  cols_dis <- function(x) {
    switch(
      direction,
      x = c("VALUE"),
      y = c("VALUE"),
      xy = c("VALUE")
    )
  }

  cols_qq <- function(x) {
    switch(
      direction,
      x = x$x
    )
  }

  cols_eta_conts <- function(x) {
    switch(
      direction,
      y = "VALUE"
    )
  }

  cols <- switch(
    x[["ptype"]],
    SCATTER = cols_res(x),
    IND = cols_ind(x),
    DIS = cols_dis(x),
    PMX_QQ = cols_qq(x),
    ETA_COV = cols_eta_conts(x)
  )
  cols <- intersect(cols, names(dx))
  if (length(cols) > 0) {
    dx[, (cols) := lapply(.SD, match.fun(trans)), .SDcols = (cols)]
  }
  dx
}





pmx_remove_plot <- function(self, private, pname, ...) {
  private$.plots_configs[[pname]] <- NULL
  private$.plots[[pname]] <- NULL
  invisible(self)
}

pmx_get_config <- function(self, private, pname) {
  pname <- tolower(pname)
  private$.plots_configs[[pname]]
}

pmx_set_config <- function(self, private, pname, new) {
  pname <- tolower(pname)
  private$.plots_configs[[pname]] <- new
}


pmx_dequeue_plot <- function(self) {
  ## assert_that(is_none_empty_queue(self))

  if (length(self$report_queue)) {
    first <- self$report_queue[[1]]
    self$report_queue <- self$report_queue[-1]
    first
  } else {
    message("Warning: Chunk has plots that were not registered within ggPMX. Footnotes may be wrong.")
  }
}

pmx_fig_process_init <- function(self) {
  report_queue <- list()
  report_n <- 0
}

pmx_fig_process_wrapup <- function(self) {
  assert_that(is_empty_queue(self))
}

pmx_get_plot <- function(self, private, pname) {
  pname <- tolower(pname)
  private$.plots[[pname]]
}

pmx_plots <- function(self, private) {
  names(private$.plots)
}

pmx_post_load <- function(self, private) {
  res <- post_load(
    self$data, self$input, self$config$sys,
    self$config$plots,
    occ = get_occ(self)
  )

  self$data <- res$data
  self$warnings <- res$warnings
}

#' Print pmxClass object
#'
#' @param x pmxClass object
#' @param ... additinal arguments to pass to print
#'
#' @family pmxclass functions
#' @return print object to screen
#' @export

print.pmxClass <- function(x, ...) {
  x$print(...)
}



#' Creates a deep copy of the controller
#'
#' @param ctr \code{pmxClass} object
#' @param keep_globals \code{logical} if TRUE we keep the global parameters changed by pmx_settings
#' @param ...  extra parameters passed to \code{pmx_settings}
#'
#' @return an object of \code{pmxClass}
#' @export
#' @details
#'
#' The controller is an `R6` object, it behaves like a reference object.
#' Some functions ( methods) can have a side effect on the controller and modify it internally.
#' Technically speaking we talk about chaining not piping here. However ,
#' using \code{pmx_copy} user can work on a copy of the controller.
#'
#' By defaul the copy don't keep global parameters setted using pmx_settings.

#'
#' @examples
#'  ctr <- theophylline()
#'  cctr <- ctr %>% pmx_copy
#'  ## Any change in the ctr has no side effect in the ctr and vice versa
pmx_copy <- function(ctr, keep_globals=FALSE, ...) {
  assert_that(is_pmxclass(ctr))
  cctr <- ctr$clone()
  params <- as.list(match.call(expand.dots = TRUE))[-1]
  params <- lang_to_expr(params)

  ## params <- list(...)
  if (!keep_globals) {
    nn <- rev(names(formals(pmx_settings)))[-1]
    eff_nn <- intersect(nn, names(params))
    if (length(eff_nn) > 0) {
      cctr$settings <- do.call(pmx_settings, params[eff_nn])
    }
  }
  cctr
}
