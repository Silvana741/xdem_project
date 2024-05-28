#!/usr/bin/env Rscript

# Do not create Rplots.pdf in non-interactive mode
if(!interactive()) pdf(NULL)
pdf("Strong_Scalability_Plots.pdf")
library(here)
library(tidyverse)
library(ggplot2)
library(ggstream)
here::i_am("plot_strong_scalability.R")
source(here("./xdem_perf_data.R"))

args <- commandArgs(trailingOnly = TRUE)
#args<- c("--nnodes=1:../data/CFG_Biomass_Furnace/XDEM_NbThreads/CFG91cd409d_XDEMfbec735a_FurnaceInputs_NormalSizeParticles_10s_MPI04_OMP01_Mainloop_Stats.h5", "--nnodes=2:../data/CFG_Biomass_Furnace/XDEM_NbThreads/CFG91cd409d_XDEMfbec735a_FurnaceInputs_NormalSizeParticles_10s_MPI04_OMP02_Mainloop_Stats.h5", "--nnodes=4:../data/CFG_Biomass_Furnace/XDEM_NbThreads/CFG91cd409d_XDEMfbec735a_FurnaceInputs_NormalSizeParticles_10s_MPI04_OMP04_Mainloop_Stats.h5" ,"--nnodes=8:../data/CFG_Biomass_Furnace/XDEM_NbThreads/CFG91cd409d_XDEMfbec735a_FurnaceInputs_NormalSizeParticles_10s_MPI04_OMP08_Mainloop_Stats.h5")
#args<- c(" --ncores=1:/home/alex/MHPC/sohpc-2022-performance-comparison-for-xdem/data/CFG_Biomass_Furnace/XDEM_NbThreads/CFG91cd409d_XDEMfbec735a_FurnaceInputs_NormalSizeParticles_10s_MPI04_OMP01_Mainloop_Stats.h5", "--ncores=2:/home/alex/MHPC/sohpc-2022-performance-comparison-for-xdem/data/CFG_Biomass_Furnace/XDEM_NbThreads/CFG91cd409d_XDEMfbec735a_FurnaceInputs_NormalSizeParticles_10s_MPI04_OMP02_Mainloop_Stats.h5", "--ncores=4:/home/alex/MHPC/sohpc-2022-performance-comparison-for-xdem/data/CFG_Biomass_Furnace/XDEM_NbThreads/CFG91cd409d_XDEMfbec735a_FurnaceInputs_NormalSizeParticles_10s_MPI04_OMP04_Mainloop_Stats.h5" ,"--ncores=8:../data/CFG_Biomass_Furnace/XDEM_NbThreads/CFG91cd409d_XDEMfbec735a_FurnaceInputs_NormalSizeParticles_10s_MPI04_OMP08_Mainloop_Stats.h5")

if(length(args) < 2) {
  args <- c("--help")
}

if("--help" %in% args) {
  cat("
      Strong Scalability study
 
      Arguments:
      --nnodes = x          - number of compute nodes used for the run
      --:filepath/file.h5   - relative path to the h5 file containing the data
 
      AT LEAST YOU NEED 2 FILES
      Example:
      ./test.R --nnodes=1:filepath/file.h5 --nnodes=2:filepath/file2.h5 ...  \n\n")
  
  q(save="no")
}


parseArgs <- function(x) strsplit(sub("^--nnodes=","", x), ":")
argsDF <- as.data.frame(do.call("rbind", parseArgs(args)))
ncores_list <- c(as.numeric(as.character(argsDF$V1)))
files <- c(as.character(argsDF$V2))


# Build the data
# - load the file with XDEM_read_integrated_performance_data()
# - associate a NbCores value with mutate()
# - put everything together with bind_rows()

data <-      XDEM_read_integrated_performance_data(files[1]) %>% mutate(NbCores= ncores_list[1])
for (index in 2:length(files)){
column<-XDEM_read_integrated_performance_data(files[index])%>% mutate(NbCores= ncores_list[index])
data<- bind_rows(data=data,column) 
}

#Dataframe to obtain total time of execution
total_time<-aggregate(x = data$Time, by=list(NbCores=data$NbCores), FUN=sum) %>% mutate(TimeCategory= "TOTAL")
colnames(total_time)[2] <- "Time"
total_speedup <- total_time %>%
  mutate(Speedup=Time[1]/Time,TimeCategory="Total")
total_speedup <- subset(total_speedup,select=-Time)


#print(data)
# Aggregate categories using threshold
data_aggregated <- data %>%
  group_by(NbCores) %>%     # We want to aggregate for each NbCores
  XDEM_aggregate_small_TimeCategories(threshold = 0.05) %>% arrange(TimeCategory)

# Aggregate costliest categories
data_costliest <- data %>%
  group_by(NbCores) %>%     # We want to aggregate for each NbCores
  XDEM_aggregate_small_TimeCategories(threshold = 0.25) %>% arrange(TimeCategory)

# Scalability plot
ggplot(data=data_aggregated, aes(x=as.factor(NbCores), y=Time, fill=`TimeCategory`)) +
  geom_bar(stat="identity") +
  ggtitle("Barplot for time execution")+
  theme(plot.title = element_text(size = 24, face = "bold"),axis.text=element_text(size=14),axis.title=element_text(size=20,face="bold"))+
  labs(x="Number of nodes", y = "Execution Time [s]")

# Get the sequential time for each phase
data_seq <- data_aggregated %>% 
  filter(NbCores==ncores_list[1]) %>% 
  mutate(SeqTime=Time) %>%
  select(TimeCategory,SeqTime)

# Compute the speedup for each phase
data_speedup <- data_aggregated %>% 
  left_join( data_seq, by = "TimeCategory" ) %>%  # Get the sequential speedup from data_seq
  mutate(Speedup=SeqTime/Time) %>%
  select(NbCores,Speedup,TimeCategory)

# Compute the speedup for costliest
data_speedup_cost <- data_costliest %>% 
  left_join( data_seq, by = "TimeCategory" ) %>%  # Get the sequential speedup from data_seq
  mutate(Speedup=SeqTime/Time) %>%
  select(NbCores,Speedup,TimeCategory)

#Ideal case
#extracting copy for ideal case
data_ideal<-filter(data_speedup,data_speedup$TimeCategory == "Apply Dynamics Models")
data_ideal_speedup <-data_ideal %>%
  mutate(Speedup=NbCores/ncores_list[1],TimeCategory="Ideal")
data_speedup <- bind_rows(data_speedup, data_ideal_speedup)


# Compute the efficiency for each phase
data_speedup$efficiency <- data_speedup$Speedup*ncores_list[1]/data_speedup$NbCores*100


# Speedup of total execution 
total_speedup <- bind_rows(total_speedup, data_ideal_speedup)

ggplot(data=total_speedup, aes(x=NbCores, y=Speedup, color=TimeCategory, shape=TimeCategory)) +
  geom_line() + geom_point() +
  labs(x="Number of nodes", y = "Speedup")+
  ggtitle("Strong scalability of the total execution")+
  theme(plot.title = element_text(size = 18, face = "bold"),axis.text=element_text(size=14),axis.title=element_text(size=20,face="bold"))

# Speedup plot of each category
ggplot(data=data_speedup, aes(x=NbCores, y=Speedup, color=TimeCategory, shape=TimeCategory)) +
  geom_line() + geom_point() +
  labs(x="Number of nodes", y = "Speedup")+
  ggtitle("Strong scalability of every category")+
  theme(plot.title = element_text(size = 18, face = "bold"),axis.text=element_text(size=14),axis.title=element_text(size=20,face="bold"))

#Speedup plot costliest
data_speedup_cost <- data_speedup_cost %>%  slice(1:(2*length(args)))

ggplot(data=data_speedup_cost, aes(x=NbCores, y=Speedup, color=TimeCategory, shape=TimeCategory)) +
  geom_line() + geom_point() +
  labs(x="Number of nodes", y = "Speedup")+
  ggtitle("Strong scalability of the 2 costliest category")+
  theme(plot.title = element_text(size = 18, face = "bold"),axis.text=element_text(size=14),axis.title=element_text(size=20,face="bold"))


# Efficiency plot
ggplot(data=data_speedup, aes(x=NbCores, y=efficiency, color=TimeCategory, shape=TimeCategory)) +
  geom_line() + geom_point() +
  labs(x="Number of nodes", y = "Efficiency")+
  ggtitle("Efficiency of each category")+
  theme(plot.title = element_text(size = 24, face = "bold"),axis.text=element_text(size=14),axis.title=element_text(size=20,face="bold"))



if(length(args) > 6) {

#steamgraph for proportion of time execution
ggplot(data_aggregated, aes(x = NbCores, y = Time, fill = TimeCategory)) +
  geom_stream(type = "proportional",n_grid=24)+
  theme(plot.title = element_text(size = 24, face = "bold"),axis.text=element_text(size=14),axis.title=element_text(size=20,face="bold"))+
  labs(y = "Proportion of execution Time")

}

# Heatmap + Table comparison for Time
data_aggregated$NbCores<-as.character(data_aggregated$NbCores)
plot2<-mutate(data_aggregated, TimeCategory = reorder(TimeCategory, Time)) %>%
  mutate(NbCores = reorder(NbCores, as.numeric(NbCores)))  %>%
  ggplot(aes(x=NbCores,y=TimeCategory, fill=data_speedup$efficiency)) +
  geom_tile() + 
  geom_text(aes(label=round(Time,digits=2)),color= "black",size = 5) +
  scale_fill_gradientn(colours = c("red", "white", "green"),
                       values = scales::rescale(c(0.0, 50, 100))) +
#  scale_fill_gradient(low = "white", high = "red") +
  ggtitle("Time Execution heatmap")+
  theme(plot.title = element_text(size = 24, face = "bold"),axis.text=element_text(size=14),axis.title=element_text(size=20,face="bold"))+
  xlab("Number of Nodes") +
  ylab("Time category")

# Table comparison for efficiency
data_speedup<-data_speedup[!(data_speedup$TimeCategory=="Ideal"),]
data_speedup$NbCores<-as.character(data_speedup$NbCores)
plot1<-  mutate(data_speedup, NbCores = reorder(NbCores, as.numeric(NbCores)))  %>%
  ggplot(aes(x=NbCores,y=TimeCategory, fill=efficiency)) +
  geom_tile(color="white") + 
  scale_fill_gradientn(colours = c("red", "white", "green"),
                       values = scales::rescale(c(0.0, 50, 100)))  +
  geom_text(aes(label=round(efficiency,digits=2)), color= "black",size = 7)+
  ggtitle("Efficiency comparison for scalability")+
  theme(plot.title = element_text(size = 24, face = "bold"),axis.text=element_text(size=16),axis.title=element_text(size=20,face="bold")) +
  xlab("Number of Nodes") +
  ylab("Time Category")

ggplot2::ggsave(filename = "Strong_Scalability_Efficiency.pdf",
                plot = gridExtra::marrangeGrob(list(plot1, plot2), nrow = 1, ncol = 1), 
                device = "pdf", width = 18, height = 8)

dev.off() 
