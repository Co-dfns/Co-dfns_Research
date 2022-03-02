library(dplyr)
library(ggplot2)

# Terrible R code but gets the job done.

data.file <- "./Raw Performance Numbers.txt.txt"
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

df %>% ggplot(aes(x = reorder(source, time), y = time)) +
    geom_boxplot() +
    coord_flip() +
    ggtitle("Execution time of a forward and backward pass in several computational models.") +
    xlab("Computation model") +
    ylab("Execution time (s)") +
    scale_y_continuous(trans="log2")
