#################################################################################################################
# plot_community_bar_plot_gammaproteobacteria.R
# 
# A script to plot sequence abundances of groups from the class Gammaproteobacteria of each sample.
# Dependencies: data/mothur/raw.trim.contigs.good.unique.good.filter.unique.precluster.pick.nr_v138.wang.tax.summary
#               data/raw/metadata.csv
#               data/raw/group_colors.csv
# Produces: results/figures/gammaproteobacteria_bar_plot.jpg
#
#################################################################################################################

# Loading input data containing sequence abundances and subsequent input data customization
community <- read_tsv("data/mothur/raw.trim.contigs.good.unique.good.filter.unique.precluster.pick.nr_v138.wang.tax.summary") %>%
  filter(!str_detect(taxon, "^Eukaryota")) %>%
  filter(taxon!="Root")

# Remove chloroplast and mitochondrial sequences and subtract their number from higher taxonomic levels to which
# they belong
chloroplast <- filter(community, str_detect(taxon, "^Chloroplast$"))$rankID
mitochondria <- filter(community, str_detect(taxon, "^Mitochondria$"))$rankID
community <- mutate_at(community, 5:ncol(community), list(~case_when(
  rankID==str_extract(chloroplast, "(\\d+\\.){3}\\d+") ~ . - .[taxon=="Chloroplast"],
  rankID==str_extract(chloroplast, "(\\d+\\.){2}\\d+") ~ . - .[taxon=="Chloroplast"],
  rankID==str_extract(chloroplast, "(\\d+\\.){1}\\d+") ~ . - .[taxon=="Chloroplast"],
  TRUE ~ .))) %>%
  filter(!str_detect(taxon, "^Chloroplast")) %>%
  mutate_at(5:ncol(.), list(~case_when(
    rankID==str_extract(mitochondria, "(\\d+\\.){4}\\d+") ~ . - .[taxon=="Mitochondria"],
    rankID==str_extract(mitochondria, "(\\d+\\.){3}\\d+") ~ . - .[taxon=="Mitochondria"],
    rankID==str_extract(mitochondria, "(\\d+\\.){2}\\d+") ~ . - .[taxon=="Mitochondria"],
    rankID==str_extract(mitochondria, "(\\d+\\.){1}\\d+") ~ . - .[taxon=="Mitochondria"],
    TRUE ~ .))) %>%
  filter(!str_detect(taxon, "^Mitochondria")) %>%
  select(-ATCC_1, -ATCC_5, -NC_1) %>%
  mutate(`23`=`23_1`+`23_2`) %>%
  select(-`23_1`, -`23_2`) %>%
  group_by(taxlevel) %>%
  mutate_at(5:ncol(.), list(~. / sum(.) * 100)) %>%
  ungroup()

# Selection of groups for plotting
select <- filter(community,
               taxlevel==6 &
               str_detect(rankID, filter(community, str_detect(taxon, "^Gammaproteobacteria$"))$rankID)) %>%
  filter_at(6:ncol(.), any_vars(. >= 2))

plot <- filter(community,
               taxlevel==6 &
               str_detect(rankID, filter(community, str_detect(taxon, "^Gammaproteobacteria$"))$rankID)) %>%
  mutate_at(5:ncol(.), list(~. / sum(.) * 100)) %>%
  ungroup() %>%
  filter(rankID %in% select$rankID) %>%
  bind_rows(summarise_all(., list(~ifelse(is.numeric(.), 100-sum(.), paste("Other_Gammaproteobacteria"))))) %>%
# Remove last digit from rankID so for the next step
  mutate(rankID=if_else(taxon=="uncultured", str_replace(rankID, "\\.\\d+$", ""), rankID))

# Adding data to "uncultured" taxa describing the higher taxonomic level to which they belong
uncultured <- select(filter(community, rankID %in% filter(plot, taxon=="uncultured")$rankID), rankID, taxon) %>%
  rename(rankID_uncultured=rankID, taxon_uncultured=taxon)

plot <- left_join(plot, uncultured, by=c("rankID"="rankID_uncultured")) %>%
  mutate(taxon=if_else(taxon=="uncultured", paste0(taxon, "_", taxon_uncultured), taxon)) %>%
  select(-taxon_uncultured)

# Loading colors for each group on the plot
color <- read_tsv("data/raw/group_colors.csv") %>%
  select(-Taxlevel) %>%
  deframe()

# Generation of italic names for taxonomic groups
names <- parse(text=case_when(str_detect(plot$taxon, "uncultured") ~ paste0("plain('Uncultured')~italic('", str_remove(plot$taxon, "uncultured_"), "')"),
                              str_detect(plot$taxon, "unclassified") ~ paste0("italic('", str_remove(plot$taxon, "_unclassified"), "')~plain('(NR)')"),
                              plot$taxon=="OM43_clade" ~ "plain('OM43 Clade')",
                              plot$taxon=="OM60(NOR5)_clade" ~ "plain('OM60 (NOR5) Clade')",
                              plot$taxon=="SAR86_clade_ge" ~ "plain('SAR86 Clade')",
                              plot$taxon=="SUP05_cluster" ~ "plain('SUP05 Cluster')",
                              plot$taxon=="Other_Gammaproteobacteria" ~ "plain('Other')~italic('Gammaproteobacteria')",
                              TRUE ~ paste0("italic('", plot$taxon, "')")))

# Tidying the sequence abundance data
plot <- gather(plot, key="Group", value="abundance", 6:ncol(plot))

# Loading metadata
metadata <- read_tsv("data/raw/metadata.csv") %>%
  filter(ID!="23_1") %>%
  mutate(ID=str_replace(ID, "23_2", "23")) %>%
  mutate(label=str_replace(label, "24/4-18 F-2", "24/4-18 F"))

# Joining sequence abundances data and metadata
Sys.setlocale(locale="en_GB.utf8")
plot <- inner_join(metadata, plot, by=c("ID"="Group")) %>%
  mutate(taxon=factor(taxon, levels=unique(plot$taxon))) %>%
  mutate(label=factor(label, levels=metadata$label)) %>%
  mutate(date=as.Date(date, "%d.%m.%Y"))

# Selecting the relative abundance of the targeted group in the whole community, tidying the obtained data and
# joining with metadata
whole <- filter(community,
                taxlevel==3) %>%
  gather(key="Group", value="abundance", 6:ncol(.)) %>%
  filter(taxon=="Gammaproteobacteria")

whole <- inner_join(metadata, whole, by=c("ID"="Group")) %>%
  mutate(date=as.Date(date, "%d.%m.%Y"))

# Generating a common theme for plots
theme <- theme(text=element_text(family="Times"), line=element_line(color="black"),
               panel.grid=element_blank(), 
               axis.line.x=element_line(), axis.line.y=element_blank(),
               axis.ticks.x=element_line(), axis.ticks.y.left=element_line(),
               axis.text.y=element_text(size=12, color="black"),
               axis.text.x=element_blank(), axis.title.y=element_text(size=14, color="black", vjust=-0.75, hjust=0.365),
               panel.background=element_blank(), plot.margin=unit(c(5.5, 5.5, 5.5, -11), "pt"), legend.position="none",
               plot.title=element_text(size=16, hjust=0.13))

# Plots generation
f <- filter(plot, station=="F") %>%
  ggplot() +
  geom_bar(aes(x=date, y=abundance, fill=taxon), stat="identity", colour="black", size=0.3, width=8) +
  scale_fill_manual(values=color, labels=names) + 
  geom_text(data=filter(whole, station=="F"), aes(x=date, y=75, label=paste(format(round(abundance, 1), nsmall=1), "%")),
            family="Times", fontface="bold", angle=90, hjust=-1) +
  labs(x=NULL, y="%") +
  ggtitle(parse(text="bold('Seawater')")) +
  scale_x_date(breaks=seq(as.Date("2017-07-01"), as.Date("2018-11-01"), "months"),
               labels=c("Jul 2017", "Aug 2017", "Sep 2017", "Oct 2017", "Nov 2017", "Dec 2017",
                        "Jan 2018", "Feb 2018", "Mar 2018", "Apr 2018", "May 2018", "Jun 2018",
                        "Jul 2018", "Aug 2018", "Sep 2018", "Oct 2018", ""),
               limits=as.Date(c("2017-07-01", "2018-11-01")),
               expand=c(0, 0)) +
  scale_y_continuous(expand=expand_scale(mult=c(0, 0.33)), breaks=seq(0, 100, by=10)) +
  annotate("segment", x=as.Date("2017-07-01"), y=0, xend=as.Date("2017-07-01"), yend=100.5, color="black", size=0.75) +
  theme +
  theme(axis.text.x=element_text(size=12, color="black", angle=90,
                                 hjust=1, vjust=2.5, margin=margin(t=5.5, unit="pt")),
        axis.title.x=element_text(size=14, color="black"), plot.margin=unit(c(5.5, 5.5, 5.5, 5.5), "pt"),
        plot.title=element_text(size=16, hjust=0.5))

fcym <- filter(plot, station=="FCyM") %>%
  ggplot() +
  geom_bar(aes(x=date, y=abundance, fill=taxon), stat="identity", colour="black", size=0.3, width=8) +
  scale_fill_manual(values=color, labels=names) + 
  geom_text(data=filter(whole, station=="FCyM"), aes(x=date, y=75, label=paste(format(round(abundance, 1), nsmall=1), "%")),
            family="Times", fontface="bold", angle=90, hjust=-1) +
  labs(x=NULL, y="%") +
  ggtitle(parse(text="bolditalic('Cymodocea nodosa')~bold('(Mixed)')")) +
  scale_x_date(breaks=seq(as.Date("2017-11-01"), as.Date("2018-11-01"), "months"),
               labels=c("Nov 2017", "Dec 2017",
                        "Jan 2018", "Feb 2018", "Mar 2018", "Apr 2018", "May 2018", "Jun 2018",
                        "Jul 2018", "Aug 2018", "Sep 2018", "Oct 2018", ""),
               limits=as.Date(c("2017-11-01", "2018-11-01")),
               expand=c(0, 0)) +
  scale_y_continuous(expand=expand_scale(mult=c(0, 0.33)), breaks=seq(0, 100, by=10)) +
  annotate("segment", x=as.Date("2017-11-01"), y=0, xend=as.Date("2017-11-01"), yend=100.5, color="black", size=0.75) +
  theme

fcam <- filter(plot, station=="FCaM") %>%
  ggplot() +
  geom_bar(aes(x=date, y=abundance, fill=taxon), stat="identity", colour="black", size=0.3, width=8) +
  scale_fill_manual(values=color, labels=names) + 
  geom_text(data=filter(whole, station=="FCaM"), aes(x=date, y=75, label=paste(format(round(abundance, 1), nsmall=1), "%")),
            family="Times", fontface="bold", angle=90, hjust=-1) +
  labs(x=NULL, y="%") +
  ggtitle(parse(text="bolditalic('Caulerpa cylindracea')~bold('(Mixed)')")) +
  scale_x_date(breaks=seq(as.Date("2017-11-01"), as.Date("2018-11-01"), "months"),
               labels=c("Nov 2017", "Dec 2017",
                        "Jan 2018", "Feb 2018", "Mar 2018", "Apr 2018", "May 2018", "Jun 2018",
                        "Jul 2018", "Aug 2018", "Sep 2018", "Oct 2018", ""),
               limits=as.Date(c("2017-11-01", "2018-11-01")),
               expand=c(0, 0)) +
  scale_y_continuous(expand=expand_scale(mult=c(0, 0.33)), breaks=seq(0, 100, by=10)) +
  annotate("segment", x=as.Date("2017-11-01"), y=0, xend=as.Date("2017-11-01"), yend=100.5, color="black", size=0.75) +
  theme

fca <- filter(plot, station=="FCa") %>%
  ggplot() +
  geom_bar(aes(x=date, y=abundance, fill=taxon), stat="identity", colour="black", size=0.3, width=8) +
  scale_fill_manual(values=color, labels=names) + 
  geom_text(data=filter(whole, station=="FCa"), aes(x=date, y=75, label=paste(format(round(abundance, 1), nsmall=1), "%")),
            family="Times", fontface="bold", angle=90, hjust=-1) +
  labs(x="Date", y="%") +
  ggtitle(parse(text="bolditalic('Caulerpa cylindracea')~bold('(Monospecific)')")) +
  scale_x_date(breaks=seq(as.Date("2017-11-01"), as.Date("2018-11-01"), "months"),
               labels=c("Nov 2017", "Dec 2017",
                        "Jan 2018", "Feb 2018", "Mar 2018", "Apr 2018", "May 2018", "Jun 2018",
                        "Jul 2018", "Aug 2018", "Sep 2018", "Oct 2018", ""),
               limits=as.Date(c("2017-11-01", "2018-11-01")),
               expand=c(0, 0)) +
  scale_y_continuous(expand=expand_scale(mult=c(0, 0.33)), breaks=seq(0, 100, by=10)) +
  annotate("segment", x=as.Date("2017-11-01"), y=0, xend=as.Date("2017-11-01"), yend=100.5, color="black", size=0.75) +
  theme +
  theme(axis.text.x=element_text(size=12, color="black", angle=90, hjust=1, vjust=2.5,
                                 margin=margin(t=5.5, unit="pt")),
        axis.title.x=element_text(size=14, color="black", margin=margin(t=11, unit="pt")))

# Generating a plot to extract a common legend
p1 <- ggplot(plot) +
  geom_bar(aes(x=date, y=abundance, fill=taxon), stat="identity", colour="black", size=0.3, width=8) +
  scale_fill_manual(values=color, labels=names) + 
  labs(x=NULL, y="%") +
  scale_x_date(breaks=seq(as.Date("2017-07-01"), as.Date("2018-11-01"), "months"),
               labels=c("Jul 2017", "Aug 2017", "Sep 2017", "Oct 2017", "Nov 2017", "Dec 2017",
                        "Jan 2018", "Feb 2018", "Mar 2018", "Apr 2018", "May 2018", "Jun 2018",
                        "Jul 2018", "Aug 2018", "Sep 2018", "Oct 2018", ""),
               limits=as.Date(c("2017-07-01", "2018-11-01")),
               expand=c(0, 0)) +
  scale_y_continuous(expand=c(0, 0), breaks=seq(0, 100, by=10)) +
  theme +
  theme(legend.position="right", 
        legend.title=element_blank(), legend.text=element_text(size=12),
        legend.spacing.x=unit(0.2, "cm"), legend.justification=c("bottom"),
        legend.box.margin=margin(0, 0, 65, -20), legend.text.align=0,
        legend.key.size=unit(0.5, "cm")) +
  guides(fill=guide_legend(ncol=1))
legend <- cowplot::get_legend(p1)

# Combining plots together and saving
p <- cowplot::ggdraw() +
  cowplot::draw_plot(f, x=0.068, y=0.708, width=0.932, height=0.288) +
  cowplot::draw_plot(fcym, x=0.309, y=0.545, width=0.689, height=0.228) +
  cowplot::draw_plot(fcam, x=0.309, y=0.317, width=0.689, height=0.228) +
  cowplot::draw_plot(fca, x=0.309, y=0, width=0.689, height=0.317) +
  cowplot::draw_plot(legend, x=0.115, y=0.28, width=0.1, height=0.2) +
  cowplot::draw_label("Oct 2017", x=0.328, y=0.720, hjust=0, fontfamily="Times", size=12, angle=90)
ggsave("results/figures/gammaproteobacteria_bar_plot.jpg", p, width=210, height=297, units="mm")