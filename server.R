shinyServer(
  function(input, output, session)
  {
    #reactive part of the data frame
    d=reactive(
    {
    get_indeed <- function(start,dest){
      url <- paste0("http://rss.indeed.com/rss?q=",input$field,"&l=",input$loc,"&start=",start)
      #download.file(url,destfile=dest,method="wget")
      return(url)
    }
    
    #dir.create("data/indeed/",recursive=TRUE,showWarnings=FALSE)
    descriptions <-c()
    for(i in seq(10,100,length.out=10)){
      dest = paste0("data/indeed/",i/10,".html")

      #Call function based on those values, a destination directory, and a specified limit#
      url = get_indeed(i, dest)
      new <- read_xml(url) %>%
        html_nodes("description") %>% html_text() 
      descriptions <- c(descriptions,new)
    }
    
    #files <- dir("/srv/connect/apps/indeed/", pattern = "*.html", full.names = TRUE)
    
    #descriptions <-c() #create a vector to store the results
    #for (i in 1:length(files)){
    #  new <- read_xml(files[i]) %>%
    #    html_nodes("description") %>% html_text() 
    #  descriptions <- c(descriptions,new)
    #}
    
    pos <- function(ele){
      sent_token_annotator <- Maxent_Sent_Token_Annotator()
      word_token_annotator <- Maxent_Word_Token_Annotator()
      annotations <- annotate(ele, list(sent_token_annotator, word_token_annotator))
      pos_tag_annotator <- Maxent_POS_Tag_Annotator()
      pos_tag_annotator
      pos <- annotate(ele, pos_tag_annotator, annotations)
      return (pos$features[[2]]$POS == "NN")
    }
    
    #get rid of the tags#
    for (i in 1:length(descriptions)){
      if (!is.na(str_extract(descriptions[i],".*\\."))){
        descriptions[i] = str_extract(descriptions[i],".*\\.")
      }
    }
    
    #remove duplicate entries
    descriptions <- unique(descriptions) 
    descriptions = descriptions[which(descriptions != "")]
    
    corp <- Corpus(VectorSource(descriptions))
    #dtm = DocumentTermMatrix(corp,control=list(removePunctuation=TRUE,removeNumbers=TRUE,stemming=TRUE))
    
    corp<-tm_map(corp,content_transformer(removeNumbers)) #convert to lower case#
    corp<-tm_map(corp,removePunctuation) #remove punctuation#
    #corp <- tm_map(corp, stemDocument)
    corp <-tm_map(corp, removeWords, stopwords('english'))
    
    dtm <- as.matrix(DocumentTermMatrix(corp))
    
    
    
    
    
    #TFIDF
    norm <- dtm/rowSums(dtm) #normalize the matrix
    nonZero <- colSums(norm != 0)
    weight <- log(dim(norm)[2]/nonZero)
    weight_sorted <- sort(weight,decreasing=TRUE)
    names <- names(weight_sorted)
    weight_matrix <- matrix(0,dim(norm)[1],dim(norm)[2])
    for (i in 1:dim(norm)[2]){
      weight_matrix[,i] <- norm[,i]*weight[i]
    }
    colnames(weight_matrix) <- colnames(norm)
    rownames(weight_matrix) <- rownames(norm)
    
    sent_token_annotator <- Maxent_Sent_Token_Annotator()
    word_token_annotator <- Maxent_Word_Token_Annotator()
    annotations <- annotate(colnames(weight_matrix), list(sent_token_annotator, word_token_annotator))
    pos_tag_annotator <- Maxent_POS_Tag_Annotator()
    pos_tag_annotator
    pos <- annotate(colnames(weight_matrix), pos_tag_annotator, annotations)
    
    
    non <- c()
    for (i in 2:length(pos)){
      if (pos$features[[i]]$POS != "NN"){
        non <- c(non,i-1)
      }
    }
    
    #non_verb <- c()
    #for (i in 2:length(pos)){
    #if (pos$features[[i]]$POS != "VBD" ||pos$features[[i]]$POS != "VBG" ){
    #non_verb<- c(non_verb,i-1)
    #}
    #}
    
    irrelevant <- c()
    for (i in 1:dim(weight_matrix)[2]){
      if (str_detect(colnames(weight_matrix)[i],"job")||str_detect(colnames(weight_matrix)[i],"http")||str_detect(colnames(weight_matrix)[i],"indeed")){
        irrelevant <- c(irrelevant,i)
      }
    }
    
    #weight_matrix <- weight_matrix[,-irrelevant]
    weight_matrix <- weight_matrix[,-c(non,irrelevant)]
    #weight_matrix <-weight_matrix[,-non_verb]
    #foreach(i = 1:dim(weight_matrix)[2]) %do% if (!pos(colnames(weight_matrix)[i])){weight_matrix[,-i]}  
    
    
    
    #Source: http://www.r-bloggers.com/text-mining/#
    v = sort(colSums(weight_matrix), decreasing=TRUE);
    myNames = names(v);
    d = data.frame(word=myNames, freq=v)
    }
    )
    
    print(d)
    
    #Render Plots for Total Number of Socks and Proportion of Socks#
    output$plot = renderPlot(
      {
        wordcloud(words =d()$word, colors=brewer.pal(8,"Dark2"), 
                  freq = d()$freq, max.words=input$num, min.freq=min(d()$freq))
      }
    )
    
    output$table = renderTable(
      {
        table = d()[1:input$num,]
        rownames(table) = 1:input$num
        names(table) = c("Word","Frequency")
        table
      }
    )
    
  }
)