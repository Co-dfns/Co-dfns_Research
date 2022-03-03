library(dplyr)
library(ggplot2)

# Terrible R code but gets the job done.

data.file <- "./Raw Performance Numbers.txt"
data <- as.matrix(read.csv(data.file, header = FALSE, sep = " "))

times <- c()
sources <- c()
for (i in (1:nrow(data))) {
    for (j in (2:ncol(data))) {
        sources <- c(sources, as.character(data[i, 1]))
        times <- c(times, data[i, j])
    }
}

df <- data.frame(time = as.numeric(times), source = sources)

orig_sources <- c("Dyalog", "Co-dfns(CPU)", "PyTorch(CPU)", "Co-dfns(GPU)", "PyTorch(SMP)", "PyTorch(GPU)")
colours <- c("#fc9732", "#4787e6", "#ff002b", "#284b80", "#cc0023", "#800016")
df %>% group_by(source) %>%
    summarise(meant = mean(time), min = min(time), max = max(time)) %>%
    ggplot(aes(x = reorder(source, meant), y = meant, min = min, max = max, nudge = max - min)) +
    geom_col(aes(fill = source)) +
    geom_pointrange(aes(ymin = min, ymax = max)) +
    geom_errorbar(aes(ymin = min, ymax = max), width = .3) +
    geom_text(aes(label = round(meant, 2)), nudge_y = 4) +
    coord_flip() +
    theme_bw() +
    ggtitle("Execution time of a forward and backward pass in several computational models.") +
    xlab("Computation model") +
    ylab("Execution time (s)") +
    scale_fill_manual(values = colours, limits = orig_sources)
    # scale_y_continuous(trans = "log2", breaks = c(2, 4, 8, 16, 32, 64))
    # stat_summary(geom="text", fun.y = median, aes(label = sprintf("%2.2f", 2^..y..)), position=position_nudge(y=.2))
