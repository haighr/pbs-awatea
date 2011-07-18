# plotDensPOPpars.r - editing scapeMCMC::plotDens for parameters,
#  to put MPDs on. AME. 26th Oct 2010.
plotDensPOPpars =
    function (mcmc, probs = c(0.025, 0.975), points = FALSE, axes = TRUE, 
    same.limits = FALSE, between = list(x = axes, y = axes), 
    div = 1, log = FALSE, base = 10, main = NULL, xlab = NULL, 
    ylab = NULL, cex.main = 1.2, cex.lab = 1, cex.strip = 0.8, 
    cex.axis = 0.7, las = 0, tck = 0.5, tick.number = 5, lty.density = 1, 
    lwd.density = 3, col.density = "black", lty.median = 2, lwd.median = 1, 
    col.median = "darkgrey", lty.outer = 3, lwd.outer = 1, col.outer = "darkgrey", 
    pch = "|", cex.points = 1, col.points = "black", plot = TRUE,
    MPD.height = 0.04,  ...)    # MPD.height, how far up to put MPD
{
    panel.dens <- function(x, ...) {
        if (any(is.finite(x)) && var(x) > 0) 
            panel.densityplot(x, lty = lty.density, lwd = lwd.density, 
                col.line = col.density, plot.points = points, 
                pch = pch, cex = cex.points, col = col.points, 
                ...)
        else panel.densityplot(x, type = "n", ...)

        panel.abline(v = quantile(x, probs = probs), lty = lty.outer, 
            lwd = lwd.outer, col = col.outer)
        panel.abline(v = median(x), lty = lty.median, lwd = lwd.median, 
            col = col.median)
                panel.xyplot(x[1], current.panel.limits()$ylim[2]*MPD.height,
                     pch=19, col="red") # AME, MPD. 0.04 of way up
                                        #  assumes ..ylim[1]=0
        panel.xyplot(x[1], current.panel.limits()$ylim[2]*MPD.height,
                     pch=1, col="black") #AME
    }
    relation <- if (same.limits) 
        "same"
    else "free"
    if (is.null(dim(mcmc))) {
        mcmc.name <- rev(as.character(substitute(mcmc)))[1]
        mcmc <- matrix(mcmc, dimnames = list(NULL, mcmc.name))
    }
    mcmc <- if (log) 
        log(mcmc/div, base = base)
    else mcmc/div
    mcmc <- as.data.frame(mcmc)
    n <- nrow(mcmc)
    p <- ncol(mcmc)
    x <- data.frame(Factor = ordered(rep(names(mcmc), each = n), 
        names(mcmc)), Draw = rep(1:n, p), Value = as.vector(as.matrix(mcmc)))
    require(grid, quiet = TRUE, warn = FALSE)
    require(lattice, quiet = TRUE, warn = FALSE)
    if (trellis.par.get()$background$col == "#909090") {
        for (d in dev.list()) dev.off()
        trellis.device(color = FALSE)
    }
    mymain <- list(label = main, cex = cex.main)
    myxlab <- list(label = xlab, cex = cex.lab)
    myylab <- list(label = ylab, cex = cex.lab)
    myrot <- switch(as.character(las), `0` = 0, `1` = 0, `2` = 90, 
        `3` = 90)
    myscales <- list(y = list(draw = FALSE, relation = "free"), 
        x = list(draw = axes, relation = relation, cex = cex.axis, 
            tck = tck, tick.number = tick.number, rot = myrot))
    mystrip <- list(cex = cex.strip)
    graph <- densityplot(~Value | Factor, panel = panel.dens, 
        data = x, as.table = TRUE, between = between, main = mymain, 
        xlab = myxlab, ylab = myylab, par.strip.text = mystrip, 
        scales = myscales, ...)
    if (!log) {
        if (is.list(graph$y.limits)) 
            graph$y.limits <- lapply(graph$y.limits, function(y) {
                y[1] <- 0
                return(y)
            })
        else graph$y.limits[1] <- 0
    }
    if (plot) {
        print(graph)
        invisible(x)
    }
    else {
        invisible(graph)
    }
}
 