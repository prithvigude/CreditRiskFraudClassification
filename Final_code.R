---
title: "BAwithR_Project_CreditFraudrisk"
author: "Prithvi Gude"
date: "November 20, 2018"
output: html_document
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

## R Markdown

This is an R Markdown document. Markdown is a simple formatting syntax for authoring HTML, PDF, and MS Word documents. For more details on using R Markdown see <http://rmarkdown.rstudio.com>.

When you click the **Knit** button a document will be generated that includes both content as well as the output of any embedded R code chunks within the document. You can embed an R code chunk like this:

```{r InstallingPackagesandreadingdata}

library(tidyverse)
library(ggthemes)
library(corrplot)
library(GGally)
library(DT)
library(caret)
library(dplyr)

library(modelr)
library(ggplot2)
loan <- read.csv("loan.csv")
summary(loan)
colnames(loan)

Removenoinfo=function(datagiven){
datagiven = datagiven%>%
        filter(loan_outcome %in% c(0 , 1))
datagiven$loan_outcome = as.numeric(datagiven$loan_outcome)
return(datagiven)
}
```

## Including Plots

You can also embed plots, for example:

```{r Data modelling}

#Defining the Output Variable: 
#We created the binary loan_outcome which will be our response variable.
#We exclude some independent variables in order to make the model simpler.
#We split the dataset to training set(75%) and testing set(25%) for the validation.
#We train a model to predict the probability of default.

# Splitting the  dataset 
# Create the new dataset by filtering 0's and 1's in the loan_outcome column and remove loan_status column for the modelling
#Creating a new output Variable called loan_outcome

View(loan)
loannew <- loan[,-c(19:24,27,29,30,51,54:74)]

#Deleting the columns which have lots of missing values NA and also irrelevant variables like URL and description
#Now we have 44 variables instead of the initial 75 variables

loannew = loannew %>%
  dplyr::mutate(loan_outcome = ifelse(loan_status %in% c('Charged Off' , 'Default') , 
                                     1, 
                                     ifelse(loan_status == 'Fully Paid' , 0 , 'No info')
                                     ))

loan2 = loannew%>%
        select(-loan_status) %>%
        filter(loan_outcome %in% c(0 , 1))

loan2$loan_outcome = as.numeric(loan2$loan_outcome)
loan2=na.omit(loan2)
#Choosing only 100000 values instead of the total 8 lakh variables
#idxfull = sample(dim(loan2)[1] , 100000 , replace = F)
#loan2=loan2[idxfull,]





loan2master<-loan2


```
##Now we have the output outcome variable: loan_outcome with two levels 0 and 1
```{r ExploratoryDataAnalysis}
#Exploratory data analysis

#bar plot for loan outcome
barplot(table(loan2master$loan_outcome) , col = 'darkorchid',legend.text='Distribution of loan outcomes')

#To explore the relationship between int_rate and the factor grade
ggplot(loan2master , aes(x = grade , y = int_rate , fill = grade)) + 
        geom_boxplot() + 
        theme_igray() + 
        labs(y = 'Interest Rate' , x = 'Grade')

#Grouping based on grade. And interpreting the results for loan_outcome
table(loan2master$grade , factor(loan2master$loan_outcome , c(0 , 1) , c('Fully Paid' , 'Default')))

ggplot(loan2master , aes(x = grade , y = ..count.. , fill = factor(loan_outcome , c(1 , 0) , c('Default' , 'Fully Paid')))) + 
        geom_bar() + 
        theme(legend.title = element_blank())

#Explore the impact of annual income on loan_amount and int_rate
ggplot(loan2master[sample(24411 , 1000) , ] , aes(x = annual_inc , y = loan_amnt , color = int_rate)) +
        geom_point(alpha = 0.5 , size = 1.5) + 
        geom_smooth(se = F , color = 'darkred' , method = 'loess') +
        xlim(c(0 , 300000)) + 
        labs(x = 'Annual Income' , y = 'Loan Ammount' , color = 'Interest Rate')
```


```{r FeatureSelection}

#Removing the NA values and evaluating only numberic variables first
loan2onlynumeric <- loan2[,-c(6,9,10:13,15:18,27,37,39,40)]
loan2onlynumeric <- loan2onlynumeric[,-c(10,13,27,28)]
loan2onlynumeric <- loan2onlynumeric[,-c(23)]

loan2onlynumeric$loan_outcome <- as.numeric(loan2onlynumeric$loan_outcome)
linearmodel <- lm(loan_outcome~.,loan2onlynumeric)
summary(linearmodel)

#From the summary of the linear model we can choose only the best numeric factors to be the ones with more significance, We will probability less than <2e-16
#funded_amnt              4.595e-05  2.475e-06  18.569  < 2e-16 ***
#int_rate                 3.268e-03  1.951e-04  16.746  < 2e-16 ***
#installment              1.593e-04  1.028e-05  15.490  < 2e-16 ***
#annual_inc              -1.053e-07  1.207e-08  -8.718  < 2e-16 ***
#open_acc                 1.748e-03  1.938e-04   9.019  < 2e-16 ***
#pub_rec                 -5.952e-03  1.634e-03  -3.642 0.000271 ***
#revol_util               3.023e-04  3.041e-05   9.940  < 2e-16 ***
#total_acc               -7.531e-04  8.192e-05  -9.193  < 2e-16 ***
#out_prncp_inv           -5.050e-05  1.310e-06 -38.556  < 2e-16 ***
# Select only the columns mentioned above and a few variables from the factor variables which might contribute to loan_outcome

loan2master<-loan2%>%
  dplyr::select(funded_amnt,int_rate,installment,annual_inc ,open_acc,pub_rec,revol_util,total_acc,out_prncp_inv, loan_amnt , grade , emp_length ,term,loan_outcome)

  
loan2masteronlynumeric = loan2master %>%
        dplyr::select(funded_amnt,int_rate,installment,annual_inc ,open_acc,pub_rec,revol_util,total_acc,out_prncp_inv, loan_amnt ,loan_outcome)


#To reduce rank-deficicency or if the variables are highly correlated. We need to remove these rankd defencies by eliminating the vairables which are highly correlated
Cormatrix <- cor(loan2masteronlynumeric)
#Finding the variables which are highly correlated
indiceswithhighestcorrelation<-which(subset(Cormatrix>0.75 & Cormatrix<1))
Cormatrix[indiceswithhighestcorrelation]
#From the correlation analysis we see that loan_amnt,funded_amnt and installment are hightly correlated. Hence eliminating the variable funded_amnt which is commonly correlated.
loan2masteronlynumeric <- loan2masteronlynumeric[,-c(1)]
#now eliminating  funded_amnt from loan2master also
loan2master = loan2 %>%
        dplyr::select(int_rate,installment,annual_inc ,open_acc,pub_rec,revol_util,total_acc,out_prncp_inv, loan_amnt , grade , emp_length ,term,loan_outcome)

#Now in our master data set we have 14 variables which lead to  the predictor loan_outcome

#Train and test data : 
set.seed(3)
idx = sample(dim(loan2master)[1] , 0.75*dim(loan2master)[1] , replace = F)
trainset = loan2master[idx , ]
testset = loan2master[-idx , ]
trainsetonlynumeric = loan2masteronlynumeric[idx , ]
testsetonlynumeric = loan2masteronlynumeric[-idx , ]
```

```{r DataModellingandbestmodel}

loan2master$loan_outcome <- as.factor(loan2master$loan_outcome)
glm.model = glm(loan_outcome ~ . , trainset, family = binomial(link = 'logit'))
summary(glm.model)


#1)Model Evaluation for logistic regression

thresholdparameter <- 0.01
#Writing a function to get the optimum value of threshold parameter for maximum accuracy

logitaccuracy.fn=function(thresholdparamter,testset,trainset){
  glm.model = glm(loan_outcome ~ . , trainset, family = binomial(link = 'logit'))
  testset$prob=predict(glm.model,testset,type="response")
  threshold <- mean(testset$prob)+thresholdparameter*sd(testset$prob)
  testset$loan_outcomepredicted=0
  testset$loan_outcomepredicted[testset$prob>threshold]=1
  A=mean(testset$loan_outcome==testset$loan_outcomepredicted) #Proportion of Correct prediction
  
  return(A)
  }
#looping it for threshold parameter from 0.01 to 400 and finding the highest value of accuracy A . That is we are varying the threshold from 
#mean+0.01*sd till mean+4*sd to get the best threshold for the best accuracy

P=1:600 #initializing
for(i in 1:600){
  print("The iteration number is")
  print(i)
  thresholdparameter=i*0.01
  
  P[i]=logitaccuracy.fn(thresholdparamter,testsetonlynumeric,trainsetonlynumeric)
}

optimumthresholdlogistic <- which.max(P)
optimumAccuracyLogistic <- max(P) 

#We found the optimum threshold to be mean(testset$prob)+3.19*sd(testset$prob) and the best accuracy to be 82.5% as above

# for the best fit 
optimumAccuracyLogistic=logitaccuracy.fn(319,testset,trainset)
testset$prob=predict(glm.model,testset,type="response")
optimumthresholdlogisticvalue<- mean(testset$prob)+thresholdparameter*sd(testset$prob)


#2)LDA

library(MASS)
lda.pred1=lda(loan_outcome~.,data=trainset)
lda.pred1
summary(lda.pred1)

ldatest1 = predict(lda.pred1,testset)
names(ldatest1)

classes<-ldatest1$class[1:20000]

posteriorprobability<-ldatest1$posterior[1:20000,1]

table(ldatest1$class,testset$loan_outcome)

mean(ldatest1$class==testset$loan_outcome)

##The Accuracy using LDA came out to be 82.03% 


#3)KNN:

library(class)

library(dplyr)


ktrainset = trainset %>%
        dplyr::select(int_rate,installment,annual_inc ,open_acc,pub_rec,revol_util,total_acc,out_prncp_inv, loan_amnt ,loan_outcome)
dim(ktrainset)

ktestset = testset %>%
        dplyr::select(int_rate,installment,annual_inc ,open_acc,pub_rec,revol_util,total_acc,out_prncp_inv, loan_amnt ,loan_outcome)



klabel=as.data.frame(trainset$loan_outcome)
dim(klabel)

cl = klabel[,1]#converting klabel into a vector

##ktrainset<- ktrainset
##dim(ktrainset)
#ktrainset<-as.data.frame(t(trainset))
#knntest=ktestset[,-c(16,17)]
#knntest<- as.data.frame(t(knntest))
#klabel <-as.data.frame(t(klabel))
dim(ktestset)
dim(cl)

knnaccuracy.fn=function(k,cl){
  
  knn.pred=knn(ktrainset,ktestset,cl,k)
  table(knn.pred, ktestset$loan_outcome)
  A=mean(knn.pred == ktestset$loan_outcome)
  
  return(A)
  }


#looping it for k=1 to 360 and finding the highest value of accuracy A 
length(ktrainset)
length(cl)
P=1:36 #initializing
for(i in seq(from = 1, to = 360, by = 10)){
  print("This is iteration number ")
  print(i)
  P[i]=knnaccuracy.fn(i,cl)
}


optimumK <- which.max(P)
optimumAccuracy <- max(P) 
optimumK
optimumAccuracy

#4)QDA
library(MASS)
#To reduce rank-deficicency or if the variables are highly correlated. We need to remove these rankd defencies by eliminating the vairables which are highly correlated
#Source : http://www.socr.umich.edu/people/dinov/2017/Spring/DSPA_HS650/notes/20_PredictionCrossValidation.html#72_quadratic_discriminant_analysis_(qda) 
Cormatrix <- cor(ktrainset)
#Finding the variables which are highly correlated
indiceswithhighestcorrelation<-which(subset(Cormatrix>0.75 & Cormatrix<1))
Cormatrix[indiceswithhighestcorrelation]
#From the correlation analysis we see that loan_amnt,funded_amnt and installment are hightly correlated. Hence eliminating the variable funded_amnt which is commonly correlated.

qda.pred1=qda(loan_outcome~.,data=ktrainset) 



qda.pred1
summary(qda.pred1)

qdatest1 = predict(qda.pred1,ktestset)
names(qdatest1)

classes<-qdatest1$class[1:20000]

posteriorprobability<-qdatest1$posterior[1:20000,1]

table(qdatest1$class,ktestset$loan_outcome)

mean(qdatest1$class==ktestset$loan_outcome)




#5)RandomForests:
# train model with Random Forests

library(randomForest)
          class(trainset$loan_outcome)
          trainset$loan_outcome <- as.factor(trainset$loan_outcome)
          testset$loan_outcome <- as.factor(testset$loan_outcome)
          RFModel<- randomForest(loan_outcome~.,data=trainset)
          
          # View the forest results.
          print(RFModel) 
          
          # Importance of each predictor.
          print(importance(RFModel,type = 2)) 
          featuresimportance<-importance(RFModel,type=2)
          RFpredict = predict(RFModel,testset)
          names(RFpredict)
          
          RFpredictdataframe<-as.data.frame(RFpredict)
          
          RFAccuracy<-mean(RFpredictdataframe$RFpredict==testset$loan_outcome)
          library(ggplot2)
          featurenames=rownames(featuresimportance)
          meanGinivalues=featuresimportance
          ggplot(data=as.data.frame(featuresimportance),aes(x=featurenames,y=meanGinivalues))+geom_bar(stat="identity", fill="steelblue")+geom_text(aes(label=meanGinivalues), vjust=1.6, color="green", size=3.5)+ggtitle("ImportanceofFeatureswithGiniIndex")

```
