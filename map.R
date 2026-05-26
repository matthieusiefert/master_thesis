library(ggplot2)
library(sf)
library(rnaturalearth)
library(rnaturalearthdata)
library(ggspatial)
library(dplyr)
library(cowplot)
library(ggrepel)

# Data
pop <- data.frame(
  Genotype = c("ILE21","MON10","ITH1/HWN2","ZAN02","SIE13","FRA","UNG1"),
  lon = c(15.2667, 13.4284, -76.6098, 4.5123, 13.1875, -4.7319, 18.9079),
  lat = c(41.8609, 47.7994, 42.5360, 52.3519, 52.2823, 48.0394, 46.4920)
)

pop_sf <- st_as_sf(pop, coords=c("lon","lat"), crs=4326)

world <- ne_countries(scale="medium", returnclass="sf")

lakes <- ne_download(scale="medium",
                     type="lakes",
                     category="physical",
                     returnclass="sf")

colors <- c(
  "FRA" = "#FFD700",
  "ITH1/HWN2" = "#FFA500",
  "SIE13" = "#FF4500",
  "ILE21" = "#1E90FF",
  "ZAN02" = "#00FFFF",
  "MON10" = "#FFFF99",
  "UNG1" = "#32CD32"
)

lon_margin <- 20
lat_margin <- 20
xlim <- range(pop$lon) + c(-lon_margin, lon_margin)
ylim <- range(pop$lat) + c(-lat_margin, lat_margin)

bbox <- data.frame(
  xmin = xlim[1],
  xmax = xlim[2],
  ymin = ylim[1],
  ymax = ylim[2]
)

# -------------------------
# Main map
# -------------------------
main_map <- ggplot() +
  
  # Ocean
  geom_rect(aes(xmin=-180, xmax=180, ymin=-90, ymax=90),
            fill="white") +
  
  # Continents
  geom_sf(data=world,
          fill="grey95",
          color="grey70",
          linewidth=0.2) +
  
  # Lakes
  geom_sf(data=lakes,
          fill="white",
          color="grey85",
          linewidth=0.2) +
  
  geom_point(data=pop,
             aes(x=lon, y=lat),
             color="white",
             size=5,
             alpha=0.9) +
  
  geom_point(data=pop,
             aes(x=lon, y=lat, color=Genotype),
             size=3,
             alpha=0.9) +
  
  # Labels
  geom_label_repel(
    data=pop,
    aes(x=lon, y=lat, label=Genotype),
    size=3,
    fontface="bold",
    box.padding=0.35,
    point.padding=0.2,
    min.segment.length=0
  ) +
  
  scale_color_manual(values=colors) +
  
  coord_sf(xlim=xlim, ylim=ylim, expand=FALSE) +
  
  geom_rect(data=bbox,
            aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill=NA,
            color="red",
            linewidth=0.9) +
  
  annotation_scale(location="bl", width_hint=0.3) +
  annotation_north_arrow(location="br",
                         which_north="true",
                         style=north_arrow_fancy_orienteering) +
  
  theme_minimal() +
  theme(
    legend.position="none",
    panel.grid.major=element_line(color="grey90"),
    plot.title=element_text(size=14, face="bold", hjust=0.5)
  ) +
  
  labs(title="Geographic origin of populations",
       x=NULL, y=NULL)

# -------------------------
# Inset map
# -------------------------
inset_map <- ggplot() +
  
  geom_sf(data=world,
          fill="grey95",
          color="grey70",
          linewidth=0.2) +
  
  geom_sf(data=lakes,
          fill="white",
          color="grey85",
          linewidth=0.15) +
  
  geom_rect(data=bbox,
            aes(xmin=xmin, xmax=xmax, ymin=ymin, ymax=ymax),
            fill=NA,
            color="red",
            linetype="dashed",
            linewidth=0.8) +
  
  coord_sf(xlim=c(-180,180), ylim=c(-60,85), expand=FALSE) +
  
  theme_void() +
  theme(
    panel.background = element_rect(fill="white", color="grey50", linewidth=0.6)
  )

# -------------------------
# Assemblage
# -------------------------
final_map <- ggdraw() +
  draw_plot(main_map) +
  draw_plot(inset_map, x=0.72, y=0.62, width=0.25, height=0.30)

final_map

# Export
ggsave("population_map_final.pdf",
       final_map,
       width=10,
       height=6)