
install.packages("data.table")
install.packages("corrplot")
install.packages("randomForest")
install.packages("DMwR")
install.packages("ggplot2")
install.packages("gridExtra")
install.packages("AUC")

library(data.table)
library(corrplot)
library(randomForest)
library(DMwR)
library(ggplot2)
library(gridExtra)
library(AUC)

#read raw data

raw.dt <- read.csv("creditcard.csv")

#produce correlation matrix

corr <- cor(raw.dt, method = "pearson")

#plotting the correlation matrix - no correlations found

corrplot.mixed(corr, lower = "number", upper = "circle", tl.pos = "lt", diag = "u")

# creating the training and test datasets

rowCount <- nrow(raw.dt)
set.seed(300)

indexTraining <- sample(1:rowCount, 0.7 * rowCount)

dtTraining = raw.dt[indexTraining,]
dtTest =   raw.dt[-indexTraining,]

# applying randomforest on training set
n <- names(dtTraining)
RFForm <- as.formula(paste("Class ~", paste(n[!n %in% "Class"], collapse = " + ")))
RFdtTraining <- randomForest(RFForm,dtTraining,ntree=100,importance=T)

RFImp <- data.frame(RFdtTraining$importance)

RFImp1 <- ggplot(RFImp, aes(x=reorder(rownames(RFImp),IncNodePurity), y=IncNodePurity)) +
  geom_bar(stat="identity", fill="yellow", colour="black") +
  coord_flip() + theme_bw(base_size = 8) +
  labs(title="Prediction using RandomForest with 100 trees", subtitle="Variable importance (IncNodePurity)", x="Variable", y="Variable importance (IncNodePurity)")

RFImp2 <- ggplot(RFImp, aes(x=reorder(rownames(RFImp),X.IncMSE), y=X.IncMSE)) +
  geom_bar(stat="identity", fill="orange", colour="black") +
  coord_flip() + theme_bw(base_size = 8) +
  labs(title="Prediction using RandomForest with 100 trees", subtitle="Variable importance (%IncMSE)", x="Variable", y="Variable importance (%IncMSE)")

grid.arrange(RFImp1, RFImp2, ncol=2)

#use the trained model for prediction on the test set.

dtTest$predicted <- predict(RFdtTraining ,dtTest)

#plot confusion matrix with threshold set as 0.5

dtResult <- data.frame(dtTest$Class, round(dtTest$predicted,0))
names(dtResult) <- c("original","predicted")
freqTable <- plyr::count(dtResult)
freqTable[c("original","predicted")][freqTable[c("original","predicted")]==0] <- "Not Fraud"
freqTable[c("original","predicted")][freqTable[c("original","predicted")]==1] <- "Fraud"

ggplot(data =  freqTable, mapping = aes(x = original, y = predicted)) +
  labs(title = "Confusion matrix", subtitle = "Random forest with 100 trees") +
  geom_tile(aes(fill = freq), colour = "grey") +
  geom_text(aes(label = sprintf("%1.0f", freq)), vjust = 1) +
  scale_fill_gradient(low = "lightblue", high = "blue") +
  theme_bw() + theme(legend.position = "none")


# function to calculate ROC

calculate_roc <- function(dtTest, costFP, costFN, k=100) {
  
  TP <- function(dtTest, threshold) {
    sum(dtTest$predicted >= threshold & dtTest$Class == 1)
  }
  
  FP <- function(dtTest, threshold) {
    sum(dtTest$predicted >= threshold & dtTest$Class == 0)
  }
  
  TN <- function(dtTest, threshold) {
    sum(dtTest$predicted < threshold & dtTest$Class == 0)
  }
  
  FN <- function(dtTest, threshold) {
    sum(dtTest$predicted < threshold & dtTest$Class == 1)
  }
  
  TPR <- function(dtTest, threshold) {
    sum(dtTest$predicted >= threshold & dtTest$Class == 1) / sum(dtTest$Class == 1)
  }
  
  FPR <- function(dtTest, threshold) {
    sum(dtTest$predicted >= threshold & dtTest$Class == 0) / sum(dtTest$Class == 0)
  }
  
  Cost <- function(dtTest, threshold, costFP, costFN) {
    sum(dtTest$predicted >= threshold & dtTest$Class == 0) * costFP + 
      sum(dtTest$predicted < threshold & dtTest$Class == 1) * costFN
  }
  
  threshold_round <- function(value, threshold)
  {
    return (as.integer(!(value < threshold)))
  }
  

  ROC <- data.frame(threshold = seq(0,1,length.out=k), TPR=NA, FPR=NA)
  ROC$TP <- sapply(ROC$threshold, function(th) TP(dtTest, th))
  ROC$FP <- sapply(ROC$threshold, function(th) FP(dtTest, th))
  ROC$TN <- sapply(ROC$threshold, function(th) TN(dtTest, th))
  ROC$FN <- sapply(ROC$threshold, function(th) FN(dtTest, th))
  ROC$TPR <- sapply(ROC$threshold, function(th)TPR(dtTest, th))
  ROC$FPR <- sapply(ROC$threshold, function(th) FPR(dtTest, th))
  ROC$Cost <- sapply(ROC$threshold, function(th) Cost(dtTest, th, costFP, costFN))

  return(ROC)
}

#calculate ROC 

roc <- calculate_roc(dtTest, 1, 10, k = 100)

#plot ROC

plot(roc$FPR, roc$TPR)


  


#applying SMOTE on the training dataset

#smoteTraining <- SMOTE(Class ~., dtTraining, k = 5, perc.over = 2, perc.under = 2 )



