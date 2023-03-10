# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Script to generate Venndiagram
# Claudio Zanettini, NYC
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Libraries and import data ----
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

library(here)
library(tidyverse)
library(purrr)
library(janitor)
library(ggvenn)
library(ggVennDiagram)
theme_set(theme_bw())

to_import <- list.files(here("data", "tab_vendiagram"), pattern = "csv", full.names = TRUE)

tabs <- lapply(to_import, read.csv)
names(tabs) <- sub("\\.csv", "", list.files(here("data", "tab_vendiagram"), pattern = "csv"))


# @@@@@@@@@@@@@@@@@@@@
# Clean and check ----
# @@@@@@@@@@@@@@@@@@@

# Some cleaning to be consistent on name of columns
tabs$rna <- rename(tabs$rna, Country = Center)
tabs$rna <- rename(tabs$rna, PPCG_Donor_Id = PPCG_Donor_ID)
tabs$wgs <- rename(tabs$wgs, PPCG_Donor_Id = PPCG_Donor_ID)

df_all <- map_dfr(tabs, function(dat) {
  dat[, c("Country", "PPCG_Donor_Id")] %>%
    clean_names() %>%
    distinct(ppcg_donor_id, .keep_all = TRUE)
},
.id = "assay"
)


# Some other cleaning of labels
df_all_clean <-
  df_all %>%
  unite("assay_country", c("assay", "country"), remove = FALSE) %>%
  filter(country != "") %>%
  filter(ppcg_donor_id != "") %>%
  mutate(country = recode(country,
    "USA/WCM" = "USA",
    "Danmark" = "Denmark",
    "Canada/CPC-GENE" =  "Canada"
  ))

message("Unique Countries")
unique(df_all_clean$country)

message("Unique Donors")
length(unique(df_all_clean$ppcg_donor_id)) # 2046

# @@@@@@@@@@@@@@@
# VenDiagram----
# @@@@@@@@@@@@@@

# We split and create 3 list based on assay
ls_donors_assay <- split.data.frame(df_all_clean, df_all_clean$assay)

# Extract column that we neeed
glob_assay <- lapply(ls_donors_assay, function(dat) dat[["ppcg_donor_id"]])

ggvenn(glob_assay,
  text_size = 4,
  fill_color = c("orange", "navyblue", "darkgreen"),
  stroke_size = 0.2
) +
  labs(title = "Global: Unique Donors") +
  theme(plot.title = element_text(size = 18, hjust = 0.5))

ggsave(filename = here("figs_tabs", "ven_diagram.png"))

# @@@@@@@@@@@@
# Barplot-----
# @@@@@@@@@@@@


# Donors By Country and assay
cbb_palette <- c("white", "#E69F00", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")


df_all_clean %>%
  group_by(country, assay) %>%
  summarise(n = n(), .groups = "drop_last") %>%
  ggplot(aes(n, country, fill = country)) +
  geom_col(col = "black") +
  facet_wrap(vars(assay)) +
  geom_text(aes(x = n / 2, label = n), size = 3, hjust = 0.5, col = "black") +
  scale_fill_manual(values = cbb_palette) +
  labs(
    x = "Unique Donors",
    y = NULL
  ) +
  theme(legend.position = "none")


ggsave(filename = here("figs_tabs", "donors_country.png"), height = 5, width = 10)

# @@@@@@@@@@@@@
# Checks  -----
# @@@@@@@@@@@@@


ls_donors_assay_selected <- lapply(ls_donors_assay, function(x) {
  x %>%
    select(ppcg_donor_id, country) %>%
    pull(ppcg_donor_id)
})

unique(Reduce(function(...) intersect(...), ls_donors_assay_selected))

# @@@@@@@@@@@@@@@@@@@@@@@@@@@@
# Vann diagram for each  -----
# @@@@@@@@@@@@@@@@@@@@@@@@@@@@

# Rearranged from Luigi's original idea of code


# We split the dataframe in a list of lists
ls_country <- split.data.frame(df_all_clean, df_all_clean$country)
ls_country_assay <- lapply(ls_country, function(dat) {
  split.data.frame(dat, dat$assay)
})

# For each element of the list of country, we extract Donors Id and Plot the Venn Diagram
country_venn <- mapply(function(dat, nms) {
  title_dat <- paste0(nms, ": Unique Donors")
  ls_dat <- lapply(dat, function(x) pull(x, ppcg_donor_id))

  ggvenn(ls_dat,
    text_size = 4,
    fill_color = c("orange", "navyblue", "darkgreen"),
    stroke_size = 0.2
  ) +
    labs(title = title_dat) +
    theme(plot.title = element_text(size = 18, hjust = 0.5))
}, ls_country_assay, names(ls_country_assay), SIMPLIFY = FALSE)

# We save
mapply(
  function(p, nms) {
    ggsave(plot = p, filename = here("figs_tabs", paste0(nms, "_venn.png")), bg = "white")
  },
  country_venn, names(country_venn)
)
