#' Split facet_wrap over multiple plots
#'
#' This extension to \code{\link[ggplot2]{facet_wrap}} will allow user to split
#' a facetted plot over multiple pages. User define the specific number of rows and columns
#' per page as well as the page number to plot, and the function will
#' automatically plot in the correct panels. This will be rendered
#' in a loop to plot pages one by one.
#'
#' @inheritParams ggplot2::facet_wrap
#' @param ncol Number of rows and columns
#' @param page The page to draw
#'
#' @note If either \code{ncol} or \code{nrow} is \code{NULL} this function will
#' fall back to the standard \code{facet_wrap} functionality.
#'
#'
#' @import ggplot2
#'

facet_wrap_paginate <- function(facets, nrow = NULL, ncol = NULL,
                                scales = "fixed", shrink = TRUE,
                                labeller = "label_value", as.table = TRUE,
                                switch = NULL, drop = TRUE, dir = "h",
                                strip.position = "top", page = 1) {
  facet <- ggplot2::facet_wrap(
    facets, nrow = nrow, ncol = ncol, scales = scales,
    shrink = shrink, labeller = labeller,
    as.table = as.table,
    switch = switch, drop = drop, dir = dir,
    strip.position = strip.position
  )
  if (is.null(nrow) || is.null(ncol)) {
    facet
  } else {
    ggplot2::ggproto(
      NULL, FacetWrapPaginate, shrink = shrink,
      params = c(facet$params, list(page = page))
    )
  }
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

#' Extend facet_wrap using ggproto
#' @format NULL
#' @import ggplot2
#' @importFrom gtable gtable_add_rows gtable_add_cols
FacetWrapPaginate <-
  ggplot2::ggproto(
    "FacetWrapPaginate", ggplot2::FacetWrap,
    setup_params = function(data, params) {
      if (!is.null(params$nrow)) {
        modifyList(
          params,
          list(
            max_rows = params$nrow,
            nrow = NULL
          )
        )
      } else {
        params
      }
    },
    compute_layout = function(data, params) {
      layout <- FacetWrap$compute_layout(data, params)
      layout$page <- ceiling(layout$ROW / params$max_rows)
      layout
    },
    draw_panels = function(panels, layout, x_scales,
                           y_scales, ranges, coord, data,
                           theme, params) {
      include <- which(layout$page == params$page)
      panels <- panels[include]
      ranges <- ranges[include]
      layout <- layout[include, , drop = FALSE]
      layout$ROW <- layout$ROW - min(layout$ROW) + 1
      x_scale_ind <- unique(layout$SCALE_X)
      x_scales <- x_scales[x_scale_ind]
      layout$SCALE_X <- match(layout$SCALE_X, x_scale_ind)
      y_scale_ind <- unique(layout$SCALE_Y)
      y_scales <- y_scales[y_scale_ind]
      layout$SCALE_Y <- match(layout$SCALE_Y, y_scale_ind)
      table <- FacetWrap$draw_panels(
        panels, layout,
        x_scales, y_scales,
        ranges, coord, data,
        theme, params
      )
      if (max(layout$ROW) != params$max_rows) {
        spacing <- theme$panel.spacing.y %||% theme$panel.spacing
        missing_rows <- params$max_rows - max(layout$ROW)
        strip_rows <- unique(
          table$layout$t[grepl("strip", table$layout$name) &
            table$layout$l %in% panel_cols(table)$l]
        )
        strip_rows <-
          strip_rows[as.numeric(table$heights[strip_rows]) != 0]
        axis_b_rows <-
          unique(table$layout$t[grepl("axis-b", table$layout$name)])
        axis_b_rows <-
          axis_b_rows[as.numeric(table$heights[axis_b_rows]) != 0]
        axis_t_rows <-
          unique(table$layout$t[grepl("axis-t", table$layout$name)])
        axis_t_rows <-
          axis_t_rows[as.numeric(table$heights[axis_t_rows]) != 0]
        table <- gtable_add_rows(table, unit(missing_rows, "null"))
        table <- gtable_add_rows(table, spacing * missing_rows)
        if (length(strip_rows) != 0) {
          table <-
            gtable_add_rows(
              table,
              min(table$heights[strip_rows]) * missing_rows
            )
        }
        if (params$free$x) {
          if (length(axis_b_rows) != 0) {
            table <-
              gtable_add_rows(
                table,
                min(table$heights[axis_b_rows]) * missing_rows
              )
          }
          if (length(axis_t_rows) != 0) {
            table <-
              gtable_add_rows(
                table,
                min(table$heights[axis_t_rows]) * missing_rows
              )
          }
        }
      }
      if (max(layout$COL) != params$ncol) {
        spacing <- theme$panel.spacing.x %||% theme$panel.spacing
        missing_cols <- params$ncol - max(layout$COL)
        strip_cols <-
          unique(
            table$layout$t[
              grepl("strip", table$layout$name) &
                table$layout$t %in% panel_rows(table)$t
            ]
          )
        strip_cols <- strip_cols[as.numeric(table$widths[strip_cols]) != 0]
        axis_l_cols <-
          unique(table$layout$l[grepl("axis-l", table$layout$name)])
        axis_l_cols <- axis_l_cols[as.numeric(table$widths[axis_l_cols]) != 0]
        axis_r_cols <-
          unique(table$layout$l[grepl("axis-r", table$layout$name)])
        axis_r_cols <- axis_r_cols[as.numeric(table$widths[axis_r_cols]) != 0]
        table <- gtable_add_cols(table, unit(missing_cols, "null"))
        table <- gtable_add_cols(table, spacing * missing_cols)
        if (length(strip_cols) != 0) {
          table <-
            gtable_add_cols(
              table,
              min(table$widths[strip_cols]) * missing_cols
            )
        }
        if (params$free$y) {
          if (length(axis_l_cols) != 0) {
            table <-
              gtable_add_cols(
                table,
                min(table$widths[axis_l_cols]) * missing_cols
              )
          }
          if (length(axis_r_cols) != 0) {
            table <-
              gtable_add_cols(
                table,
                min(table$widths[axis_r_cols]) * missing_cols
              )
          }
        }
      }
      table
    }
  )

#' Determine the number of pages in a paginated facet plot
#'
#' This is a simple helper that returns the number of pages it takes to plot all
#' panels when using \code{\link{facet_wrap_paginate}} . It partially builds the plot so depending
#' on the complexity of your plot it might take some time to calculate...
#'
#' @param plot A ggplot object using either facet_wrap_paginate or
#' facet_grid_paginate
#'
#' @return If the plot uses  using either facet_wrap_paginate or
#' facet_grid_paginate it returns the total number of pages. Otherwise it
#' returns NULL
#' @import ggplot2
#'
n_pages <- function(plot) {
  page <- ggplot_build(plot)$layout$panel_layout$page
  if (!is.null(page)) {
    max(page)
  } else {
    NULL
  }
}
