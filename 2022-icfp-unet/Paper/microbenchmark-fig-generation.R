library(dplyr)
library(ggplot2)

data.file <- "./micro_mx.csv"
data <- read.csv(data.file)

data %>% mutate(size = as.factor(size), channels = as.factor(channels)) %>% group_by(size, channels) %>%
    summarise(speedup = ((function(v){v[1]/v[2]})(s))) %>%  # Relative change of stencil function code w.r.t. stencil operator
    ggplot(aes(x = size, y = channels, fill = speedup)) +
    geom_tile() +
    theme_bw() +
    theme(text = element_text(size = 30)) +
    ggtitle("Stencil function vs stencil operator max pooling speedup") +
    xlab("Feature map size") +
    ylab("# of channels") +
    scale_fill_gradient(low = "#fce3ca", high = "#fc9732") +
    geom_text(aes(label = round(speedup, 2)), size = 6)

data %>% mutate(size = as.factor(size)) %>%
    group_by(size, channels) %>%
    summarise(speedup = ((function(v){v[1]/v[2]-1})(s))) %>%  # Relative change of stencil function code w.r.t. stencil operator
    ggplot(aes(x = channels, y = speedup)) +
    geom_line(aes(linetype = size)) +
    geom_point(aes(shape = size)) +
    theme_bw() +
    theme(text = element_text(size = 30)) +
    ggtitle("Stencil function vs stencil operator convolution speedup.") +
    xlab("# of channels") +
    ylab("Speedup") +
    scale_x_continuous(trans = "log2")
