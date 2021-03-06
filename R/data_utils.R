#' Compare two groups assignment results
#'
#' This function allows you to express your love of cats.
#' @param group1 vector of clustering 1
#' @param group2 vector of clustering 2
#' @keywords compare
#' @export
#' @examples
#' cat_function()
compare_group <- function(group1, group2, file.prefix="Compare.group", title="",
                          plot=T, save.image=F, add.legend=T,
                          label.size=5, title.size=36, angle=45){
  if (class(group1)=="integer" | class(group1)=="numeric")
  group1 <- paste0("Group", group1)
  if (class(group2)=="integer" | class(group2)=="numeric")
  group2 <- paste0("Group", group2)

  group1 <- factor(group1)
  group2 <- factor(group2)

  ### Calculate the percentge first before feed into ggplot2 ###
  ### This is based on group1.
  summary <- as.matrix(table(group1, group2))
  sums <- rowSums(summary)
  summary.pct <- apply(t(summary), 1, function(x) x/sums) * 100
  summary.pct <- melt(summary.pct)

  ### Stacked Bar using ggplot2
  colourCount = length(unique(summary.pct$group2))
  num <- ifelse(colourCount > 9, 9, colourCount)
  getPalette = colorRampPalette(RColorBrewer::brewer.pal(num, "Set1"))

  ray <- ggplot(data=summary.pct, aes(x=group1, y=value, fill=group2)) +
        geom_bar(stat="identity") + labs(y = "Percentage (%)") +
        scale_fill_manual(values = getPalette(colourCount)) +
        xlab('') + labs(fill="")

  ### This part is specific for manually colorign the groups to match pam50 coloring
  # xlab('') + scale_fill_manual(values=c("#E41A1C", "#fccde5", "#2166ac", "#a6cee3", "#33A02C")) # NMFK5-vs.PAM50
  # xlab('') + scale_fill_manual(values=c("#33A02C", "#fccde5", "#a6cee3", "#2166ac", "#E41A1C")) # PAM50-vs-NMFK5

  ### Add the percentage within each bar ###
  ### Get ggplot data
  naikai <- ggplot_build(ray)$data[[1]]
  ### Create values for text positions.
  naikai$position = (naikai$ymax + naikai$ymin)/2
  ### round up numbers and convert to character.
  ### We need to reorder group1, desc(group2) in order to get the correct y position
  # foo <- round(summary.pct[order(summary.pct$group1, decreasing=TRUE), "value"], digits=2)
  foo <- summary.pct %>% arrange(group1, desc(group2)) %>% .$value %>% round(digits=2)
  ### Create a column for text
  naikai$label <- paste0(foo, "%")
  ### Plot again
  ray <- ray + annotate(x = naikai$x, y = naikai$position, label = naikai$label, geom = "text", size=label.size)
  ray <- ray + ggtitle(title) + theme(plot.title=element_text(face="bold", size=title.size))
  ray <- ray + theme(axis.text.x = element_text(angle = angle, vjust = 1, hjust=1))

  # legend
  if (!add.legend){
    ray <- ray + theme(legend.position="none")
  }

  # option to plot it or not
  if(plot)
    print(ray)

  # option to save the plot or not
  if (save.image){
    pdf(paste0(file.prefix, ".pdf"), height=10, width=12)
    print(ray)
    dev.off()
  }
  # or just simply return the plot
  return (ray)
}

#' Calculate Mutual information from confusion matrix
#' @param a True positive
#' @param b False negative
#' @param c False positive
#' @param d True negative
#' @keywords mutual information
#' @export
mutual_info_from_confmatrix <- function(a, b, c, d){
  tot <- a + b + c + d
  MI <- a/tot * log( a*tot / ((a+b)*(a+c)) ) +
        b/tot * log( b*tot / ((b+a)*(b+d)) ) +
        c/tot * log( c*tot / ((c+a)*(c+d)) ) +
        d/tot * log( d*tot / ((d+b)*(d+c)) )
  return(MI)
}

#' calculate Mutual information from two vector
#'
#' first generate summary table, then use equation to calculate mutual info
#' @export
mutual_info_from_vector <- function(x, y, base=exp(1)){
  if (length(x) != length(y))
    stop("arguments must be vectors of the same length")
  x <- as.vector(x)
  y <- as.vector(y)
  N <- length(x)

  tab <- table(x, y)
  tab.da <- tab %>% data.frame
  prop.x <- tab.da %>% group_by(x) %>% summarise(freq.x = sum(Freq)/N)
  prop.y <- tab.da %>% group_by(y) %>% summarise(freq.y = sum(Freq)/N)

  inner_join(tab.da, prop.x, by="x") %>%
    inner_join(., prop.y, by="y") %>%
    mutate(prop = Freq / N) %>%
    mutate(MI = prop * log(prop /(freq.x * freq.y), base = base)) %>%
    dplyr::select(MI) %>%
    sum(na.rm=TRUE)
}

#' calculate entroyp
#'
#' @export
cal_entropy <- function(x, base=exp(1)){
  if (!is.vector(x))
    stop("arguments must be a vector")
  probs <- table(x) / length(x)
  -sum(probs * log(probs, base = base))
}

#' Calculate statistics comparing two clustering results
#'
#' @param x reference for cluster
#' @param y prediction for cluster
#' @keywords compare
#' @export
compare_groups_stats <- function(x, y, method="rand", base=exp(1), beta=1){
  x <- as.vector(x)
  y <- as.vector(y)
  if (length(x) != length(y))
    stop("arguments must be vectors of the same length")
  tab <- table(x, y)
  if (all(dim(tab) == c(1, 1)))
    return(1)

  # TP(a) | FN(b) # TPR, Recall
  # FP(c) | TN(d) # FPR, 1 - Specificity
  # --------------
  # Preci

  a <- sum(choose(tab, 2)) #TP
  b <- sum(choose(rowSums(tab), 2)) - a #FN
  c <- sum(choose(colSums(tab), 2)) - a #FP
  d <- choose(sum(tab), 2) - a - b - c  #TN
  R <- a / (a+b)
  P <- a / (a+c)
  TT <- a + d
  FF <- b + c

  if(method == "precision"){
    P
  }else if(method == "recall" | method == "tpr"){
    R
  }else if(method == "tt"){
    TT / (a+b+c+d)
  }else if(method == "ff"){
    FF / (a+b+c+d)
  }else if(method == "fpr"){
    c / (c+d)
  }else if(method == "rand"){
    (a+d) / (a+b+c+d)
  }else if(method == "adj.rand"){
    (2*a*d - 2*b*c) / (b^2 + c^2 + a*b + a*c + b*d + c*d + 2*a*d )
  }else if(method == "f.score"){
    (beta^2 + 1)*P*R / (beta^2*P + R)
  }else if(method == "purity"){
    tab %>% apply(., 2, max) %>% sum / length(x)
  }else if(method == "mi"){
    mutual_info_from_vector(x, y, base = base)
  }else if(method == "nmi"){
    mi <- mutual_info_from_vector(x, y, base = base)
    avg_entropy <- (cal_entropy(x, base = base) + cal_entropy(y, base = base)) / 2
    mi / avg_entropy
  }else if(method == "vi"){
    mi <- mutual_info_from_vector(x, y, base = base)
    cal_entropy(x, base = base) + cal_entropy(y, base = base) - 2 * mi
  }
}


#' Normalize data through DESeq size factor
#' @param countdata integer data frame
#' @keywords deseq
#' @export
#' @examples
#' deseq_norm(countdata)
deseq_norm <- function(countdata){
    coldata <- data.frame(condition=factor(rep("Tumour", ncol(countdata))))
    dds <- DESeq2::DESeqDataSetFromMatrix(countData = round(countdata),
                                          colData = coldata,
                                          design = ~ 1)
    dds <- estimateSizeFactors(dds)
    normalized.countdata <- counts(dds, normalized=TRUE)
    return(normalized.countdata)
}


#' Extract data by MAD value
#'
#' @param data Original gene expression data
#' @param topN How many genes from TopMAD list
#' @keywords MAD, extract
#' @export
#' @examples
#' extract_data_by_mad(mtcars, topN=10, type="data")
extract_data_by_mad <- function (data, topN=100, by="row", type="data"){
  by.idx <- ifelse(by=="row", 1, 2)
  data.mad.genes <- apply(data, by.idx, mad) %>%
            select_top_n(., topN, bottom=F) %>%
            names
  if(type=="data"){
    if(by=="row"){
      data <- data[rownames(data) %in% data.mad.genes, ]
    }else if(by=="col"){
      data <- data[ ,colnames(data) %in% data.mad.genes]
    }else{
      stop("Wrong parameters, by can be 'row' or 'col'")
    }
    return(data)
  }else if(type=="genes"){
    return(data.mad.genes)
  }else{
    stop("Wrong parameters, type can be 'data' or 'genes'")
  }
}

#' Extract data by 'math' operation
#'
#' @param data Original gene expression data
#' @param topN How many genes from Top 'operation' list
#' @keywords data extraction
#' @export
#' @examples
#' extract_data_by_math(mtcars, topN=10, type="data", math="mean")
extract_data_by_math <- function (data, topN=100, by="row", type="data", math="mean"){
  by.idx <- ifelse(by=="row", 1, 2)
  if(!(math %in% c("mean", "median", "max", "min", "mad"))){
    stop( paste("Unknown math operation", math, "Please check it again"))
  }
  data.mad.genes <- apply(data, by.idx, math) %>%
            select_top_n(., topN, bottom=F) %>%
            names
  if(type=="data"){
    if(by=="row"){
      data <- data[rownames(data) %in% data.mad.genes, ]
    }else if(by=="col"){
      data <- data[ ,colnames(data) %in% data.mad.genes]
    }else{
      stop("Wrong parameters, by can be 'row' or 'col'")
    }
    return(data)
  }else if(type=="genes"){
    return(data.mad.genes)
  }else{
    stop("Wrong parameters, type can be 'data' or 'genes'")
  }
}


#' Check whether it is a integer whole value
#'
#' @export
is.whole <- function(a, tol = 1e-7) {
  is.eq <- function(x,y) {
    r <- all.equal(x,y, tol=tol)
    is.logical(r) && r
  }
  (is.numeric(a) && is.eq(a, floor(a))) ||
    (is.complex(a) && {ri <- c(Re(a),Im(a)); is.eq(ri, floor(ri))})
}

#' Use data.table for faster read.table
#'
#' @param filepath input file path
#' @keywords read data
#' @export
#' @examples
#' myfread.table(system.file('sake', package='sake'))
myfread.table <- function(filepath, check.platform=T, header=T, sep="\t", detect.file.ext=T){
   ext <- tools::file_ext(filepath)
   if(detect.file.ext){
      if (ext=="csv"){
        sep=","
      }else if (ext=="out" || ext=="tsv" || ext=="txt"){
          sep="\t"
      }else{
          warning("File format doesn't support, please try again")
          return(NULL)
      }
   }

   header <- read.table(filepath, nrows = 1, header = FALSE, sep=sep, stringsAsFactors = FALSE)
   first_data <- read.table(filepath, nrows=1, sep=sep, skip=1)
   if(length(header)==length(first_data)){
      cols <- c("character", rep("numeric", length(header)-1))
   }else if(length(header)==length(first_data)-1){
      cols <- c("character", rep("numeric", length(header)))
   }
   rawdata <- fread(filepath, header=F, sep=sep, skip=1, colClasses=cols)

    ### Again. Add more checking in case there are duplicate rownames
    # read in the first column and check, if there is duplicated rownames (mostly gene names)
    # then send out a warning and then make it unique
    if(sum(duplicated(rawdata$V1))>0){
      warning("There are duplicated rownames in your data")
      warning("Please double check your gene count table")
      rawdata$V1 <- make.names(rawdata$V1, unique=TRUE)
    }

   ### Add more checking in case there are duplicated column names
   # make.names(names, unique=TRUE)
   rawdata %<>% setDF %>% magrittr::set_rownames(.$V1) %>%
                  '['(colnames(.) != "V1") #%>% as.numeric

   # data doesn't have colnames for first row (rownames)
   if(length(header) == dim(rawdata)[2]){
      # colnames(rawdata) <- unlist(header)
      colnames(rawdata) <- make.names(unlist(header), unique=TRUE)
   }else if (length(header) == dim(rawdata)[2] + 1){
      # colnames(rawdata) <- unlist(header)[-1]
      colnames(rawdata) <- make.names(unlist(header)[-1], unique=TRUE)
   }
   # Add checking data platform
   if(check.platform){
      rawdata <- detect_genecnt_platform(rawdata)
   }

   return(rawdata)
}


#' Own version of writing matrix output
#' @param countdata integer data frame
#' @keywords write.matrix
#' @export
#' @examples
#' my.write.matrix(data)
my.write.matrix <- function(x, file = "", sep = "\t", col.names=T,
   append=F,
   row.names=F,
   justify = c( "none", "left", "right"),
   pval=NULL,
   newline="\n",
   names=NULL )
{
   justify = match.arg( justify )
   x <- as.matrix(x)
   p <- ncol(x)
   cnames <- colnames(x)
   rnames <- rownames(x)

   if ( !is.null(pval) ) {
      x[,pval] <- format.pval( as.numeric(x[,pval]) )
   }
   if ( col.names && !is.null(cnames) )
   {
      x <- format(rbind( cnames, x ), justify=justify)
   }
   if ( row.names )
   {
      p <- p+1
      if ( col.names && !is.null(cnames) ) {
         rnames <- if (is.null(names)) c("",rnames) else c(names, rnames)
      }
      x <- cbind( format(rnames,justify=justify), x )
   }
   cat( t(x), file=file, sep=c(rep(sep,p - 1), newline), append=append )
}

#' Calculate DESeq normalization factor
#'
#' @param data data to be transformed
#' @keywords deseq, normalization
#' @export
#' @examples
#' norm_factors(mtcars)
norm_factors <- function(data) {
  nz <- apply(data, 1, function(row) !any(round(row) == 0))
  data_nz <- data[nz,]
  p <- ncol(data)
  geo_means <- exp(apply(data_nz, 1, function(row) (1/p) * sum(log(row)) ))
  s <- sweep(data_nz, 1, geo_means, `/`)
  apply(s, 2, median)
}


#' Remove genes that with too many constant 0 expression across samples
#'
#' Allow you to remove those data entries with constant variance
#' You can specify the percentage of 0s as the threshold
#' @param data Input data set
#' @param by Default by "row", can change to "column"
#' @keywords rmv_constant_var
#' @export
#' @examples
#' rmv_constant_0(data, by="row", pct=0.75)
rmv_constant_0 <- function(data, by="row", pct=0.75, minimum=0, verbose=FALSE){
   alt_by=""
   if(by=="row"){
      num_all_var <- dim(data)[1]
      data <- data[apply(data, 1, function(x) sum(x<=minimum)<=length(x)*pct), ]
      num_rmv_var <- dim(data)[1]
      alt_by="col"
   }else if(by=="col"){
      num_all_var <- dim(data)[2]
      data <- data[, apply(data, 2, function(x) sum(x<=minimum)<=length(x)*pct)]
      num_rmv_var <- dim(data)[2]
      alt_by="row"
   }
   if(verbose){
     message(sprintf ("Original data: %d %s, Removed %d because these %s have values below or equal to %s in more than %d percent of all %s", num_all_var, by, num_all_var-num_rmv_var, by, minimum, pct*100, alt_by))
   }
   return(data)
}


#' Transform the countdata into Reads per million reads
#'
#' @param data countdata
#' @param mapped_reads mapped reads in each library
#' @keywords RPM
#' @export
#' @examples
#' rpm(data)
rpm <- function(data, mapped_reads){
  data <- t(t(data)/mapped_reads*1000000)
}


#' Convert letter to capitalization
#'
#' @param x character
#' @keywords standardize
#' @export
#' @examples
#' simpleCap("meat is good")
simpleCap <- function(x) {
   s <- strsplit(x, " ")[[1]]
   paste(toupper(substring(s, 1,1)), substring(s, 2), sep="", collapse=" ")
}

#' Scale data base on specify metrics
#'
#' This function allows you to scale the data based on your metrics of interest
#' @param x data
#' @param scale By 'row' or 'column'
#' @param na.rm Remove NAs. Default is TRUE
#' @param method What kind of metrics? Default is 'median'. (Can be 'mean', 'median', 'mode', 'max', 'min', etc)
#' @keywords scale
#' @export
#' @examples
#' scale_data(mtcars)
scale_data <- function(x, scale="row", na.rm=TRUE, method="median"){
   if (method=="mean"){
      rowCal <- rowMeans
      colCal <- colMeans
   }else if (method=="median"){
      rowCal <- rowMedians
      colCal <- colMedians
   }
   if (scale=="column" | scale=="col" | scale=="both") {
         x <- sweep(x, 2L, colCal(as.matrix(x), na.rm = na.rm), check.margin = FALSE)
         sx <- apply(x, 2L, sd, na.rm = na.rm)
         x <- sweep(x, 2L, sx, "/", check.margin = FALSE)
   }
   if (scale=="row" | scale=="both") {
         x <- sweep(x, 1L, rowCal(as.matrix(x), na.rm = na.rm), check.margin = FALSE)
         sx <- apply(x, 1L, sd, na.rm = na.rm)
         x <- sweep(x, 1L, sx, "/", check.margin = FALSE)
   }
   if (scale=="none"){
      x <- x
   }
   return(x)
}


#' Select top number from a vector
#'
#' Select top # from a vector
#' @param data numerical data
#' @param n top number
#' @param bottom whether to select from bottom?
#' @keywords select
#' @export
#' @examples
#' select_top_n(mtcars, 100, bottom=F)
select_top_n <- function(data, n, bottom=F){
   if(bottom){
      data <- head(sort(data, decreasing = F), n=n)
   }else{
      data <- head(sort(data, decreasing = T), n=n)
   }
   return(data)
}

#' Select top n percentage of data
#'
#' @param data numerical data
#' @param n percentage to select
#' @keywords top n percent
#' @export
#' @examples
#' select_n_pct(c(1,23,1,412,51,231,516,1,23,13,3,5,1), 10)
select_n_pct <- function(data, n){
  data[data > quantile(data, prob=1-n/100)]
}


#' Select top n genes
#'
#' @param data numerical data
#' @param n number to select
#' @param whole whether to return the whole sets
#' @keywords top n percent
#' @export
#' @examples
#' top_genes(data)
top_genes <- function(data, n=20, whole=F, name="Exp1"){
  data <- as.data.table(data)
  data.summary <- data[, length(num_classes), by="string_gene_symbols"][order(-V1), ]
  setnames(data.summary, c("string_gene_symbols", name))

  if (whole){
    return(data.summary)
  }else{
    return(head(data.summary, n=n))
  }
}


#' Transform the countdata by upper quantile value from each sample
#'
#' Upper quartile normalization, add option to remove all zeros in the sample first
#' @param data countdata
#' @keywords UQ, quantile, normalization
#' @export
#' @examples
#' uq(mtcars)
uq <- function(data, remove.zero=T){
  if(remove.zero){
    upper_quartile <- apply(data, 2, function(x) quantile(x[x!=0])[4])
  }else{
    upper_quartile <- apply(data, 2, function(x) quantile(x)[4])
  }
  data.upperQ <- data %>%
                  t %>%
                  divide_by(upper_quartile) %>%
                  t %>%
                  multiply_by(100)
  return(data.upperQ)
}


VERBOSE <- function( v, ... )
{
  if ( v ) cat( ... )
}

#' Use vst (fast) in DESeq2
#' @param countdata integer data frame
#' @keywords vst, deseq2
#' @export
#' @examples
#' vst(countdata)
vst <- function(countdata, fast=TRUE){
  coldata <- data.frame(condition=factor(rep("Tumour", ncol(countdata))))
  dds <- DESeq2::DESeqDataSetFromMatrix(countData = countdata,
                                          colData = coldata,
                                          design = ~ 1)
  if(fast){
    vsd <- DESeq2::vst(dds, blind=TRUE)
  }else{
    vsd <- DESeq2::varianceStabilizingTransformation(dds, blind=TRUE)
  }
  return(SummarizedExperiment::assay(vsd))
}



#' Clustering by hierarchical
#' @param data integer data frame
#' @keywords write.matrix
#' @export
#' @examples
#' my.write.matrix(data)
clust_by_hier <- function(data, K, takelog=FALSE, method="ward.D"){
  if(takelog){
    expdata <- log2(expdata + 1)
  }
  #distance <- 1 - cor(expdata, method="spearman") %>% as.dist
  distance <- dist(t(expdata))

  res <- hclust(distance, method = method) %>%
    cutree(k = K) %>%
    data_frame(Sample_ID=names(.), groups = .) %>%
    separate(Sample_ID, into = c("GEO", "Patient", "Lane", "ID", "Celltype"))
}
