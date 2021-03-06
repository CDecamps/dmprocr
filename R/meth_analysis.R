#' get_probe_names
#'
#' This function extracts probe names of a given gene from platform
#' @param gene A vector describing the gene (line of a bed file).
#' @param meth_platform A data frame describing CpG positions.
#' @param up_str   An integer specifying up stream size (in bp).
#' @param dwn_str  An integer specifying down stream size (in bp).
#' @param pf_chr_colname string matching the name of the column in the platform that contain the chromosome on which we find a probes.
#' @param pf_pos_colname string matching the name of the column in the platform that contain the position information of probes.
#' @return A vector of probe names
#' @export
get_probe_names = function(
  gene                                ,
  meth_platform                       , 
  pf_chr_colname="Chromosome"         ,
  pf_pos_colname="Start"              ,
  up_str=5000                         , 
  dwn_str=5000                        
 ) {
   
  if (substr(meth_platform[1, pf_chr_colname], 1, 3) != "chr") {
    meth_platform[,pf_chr_colname] = paste0("chr",meth_platform[,pf_chr_colname])
  }
  if (substr(gene[[1]], 1, 3) != "chr") {
    gene[[1]] = paste0("chr",gene[[1]])
  }
    
  # get gene properties
  chr =            gene[[1]]
  strand =         gene[[6]]
  gene_name =      gene[[4]]
  beg = as.numeric(gene[[2]])
  end = as.numeric(gene[[3]])
  
  # get meth infos
  if (strand == "-") {
    off_set_beg = dwn_str
    off_set_end = up_str
    tss = end
  } else {
    off_set_beg = up_str
    off_set_end = dwn_str
    tss = beg
  }

  ## Compute probes associated with the gene 
    probe_idx =   rownames(meth_platform)[
      !is.na(meth_platform[[pf_pos_colname]]) & !is.na(meth_platform[[pf_chr_colname]]) &
      meth_platform[[pf_chr_colname]] == chr &
      meth_platform[[pf_pos_colname]] >= tss-up_str &
      meth_platform[[pf_pos_colname]] < tss+dwn_str
    ]    

  if (length(probe_idx) == 0) {
    warning(paste0("No probes for gene ", gene[[4]],"(",gene[[5]],")."))
    return(NULL)
  } else {
    return(probe_idx)    
  }
}

#'interpolate_gene
#'
#'Build a interpolated signal of differential methylation value for a gene.
#'
#'
#' @param vec A numeric vector specifying differential methylation signal.
#' @param xf coordinates of interpolation
#' @param probes_pos is a vector of probes position on the chromosome. 
#' @param tss the transcription start site on the same chromosome.
#' @param updwn_str is the width of the window on the chromosome in bp where the function will fetch probes position and differential methylation value, default is 5000.
#' @param slide is the maximum width slide you'll alow when comparing two curve, default is 0.
#'@export
interpolate_gene = function(vec, probes_pos, xf, tss, updwn_str, slide) {
  if (sum(!is.na(vec))==0) {
    return(rep(NA, length(xf)))
  }
  xp         <- probes_pos[order(probes_pos)]
  yp         <- vec[order(probes_pos)]
  idx = !is.na(yp)
  xp = xp[idx]
  yp = yp[idx]
  # xp_orig = xp
  # yp_orig = yp
  #concatenate missing bp to x axis (in order to have 10000 bp windows everytime)
  xpA = xpA = c()
  if (tss - updwn_str - slide < min(xp)) {
    xpA = tss - updwn_str - slide
  }
  if (tss + updwn_str + slide > max(xp)) {
    xpB = tss + updwn_str + slide
  }
  # xpA <- seq(from = tss - updwn_str - slide, to = min(xp)-1 )
  # xpB <- seq(from = max(xp)+1, to = tss + updwn_str + slide)
  xp  <- c(xpA, xp, xpB)
  #add fictiv value to added bp in y axis
  yp  <- c( rep(0, length(xpA)), yp, rep(0, length(xpB)) )
  ######
  yf         <- signal::pchip(xp, yp, xf)
  # yf_orig = yf#         <- signal::pchip(xp_orig, yp_orig, xf)
  # layout(matrix(1:2, 1), respect=TRUE)
  # plot(xf, yf, ylim=range(c(yf_orig, yf)))
  # points(xp_orig, yp_orig, pch=16, col=2)
  # plot(xf, yf_orig, ylim=range(c(yf_orig, yf)))
  # points(xp_orig, yp_orig, pch=16, col=2)
  
  
  return(yf)
}



#'compute_gene_meth_profile 
#'
#'Generate  differential methylation profile for a gene around the transcription start side 
#'
#' @param meth_data A matrix of row methylation data with TCGA sample ids as column names and probes ids as row names.
#' @param meth_platform a data.frame with metadata types as columns names and probes ids as row names.
#' @param gene A list that describe gene in bed format.
#' @param updwn_str is the width of the window on the chromosome in bp where the function will fetch probes position and differential methylation value
#' @param slide is the maximum width slide you'll alow when comparing two curve
#' @param wig_size is resolution at which the function interpolate the probes signal
#' @param mask_wide is mask wide of o probe
#' @param pf_chr_colname string matching the name of the column in the platform that contain the chromosome information of probes
#' @param pf_pos_colname string matching the name of the column in the platform that contain the position information of probes
#' @param apply_func Function that will be used for apply.
#'@export
compute_gene_meth_profile = function(gene, meth_data, meth_platform, pf_pos_colname, pf_chr_colname, updwn_str, slide, wig_size, mask_wide, apply_func=apply) {  
  probe_idx = get_probe_names(gene   , 
    meth_platform=meth_platform      , 
    pf_pos_colname=pf_pos_colname    ,   
    pf_chr_colname=pf_chr_colname    , 
    up_str=updwn_str+slide           , 
    dwn_str=updwn_str+slide 
  )
  
  if (length(probe_idx) == 0) {
    warning(paste0("No probes for gene ", gene[[4]],"(",gene[[5]],")."))
    return(NULL)
  } else {

    data         = meth_data[probe_idx,]
    probes_pos   = meth_platform[probe_idx, pf_pos_colname]
    strand       = gene[[6]]
    tss          = ifelse (strand == "+", as.numeric(gene[[2]]), as.numeric(gene[[3]]))

    xf = seq(tss - updwn_str - slide, tss + updwn_str + slide, by = wig_size)

    if  (length(probe_idx) == 1) {
      data = t(data)
    }

    big = apply_func(
      data , 2,
      # vec = data[,5]
      interpolate_gene      ,
      probes_pos=probes_pos ,
      xf=xf                 ,
      tss=tss               ,
      updwn_str=updwn_str               ,
      slide=slide
    )      

    mask = as.numeric(sapply(xf, function(x) {
      min(abs(x - probes_pos)) <= mask_wide
    }))

    profile = from_big_to_profile(big, xf, mask)

    if (strand == "-") {
      profile = profile[nrow(profile):1,]
    }
  
    return(profile)
  }
}

#' from_big_to_profile
#'
#' Transform a matrix of interpolated methylome signal of samples to a methyl;ome profile
#'
#' @param xf coordinates of interpolation
#' @param big matrix of interpolated methylome signal of samples 
#' @param mask is mask of o probe
#' @importFrom stats var
#'@export
from_big_to_profile = function(big, xf, mask) {
  m = apply(big, 1, mean, na.rm=TRUE)
  v = apply(big, 1, var, na.rm=TRUE)
  profile = data.frame(x=xf, y=m, var=v, mask=mask)
  profile = cbind(profile, big)
  return(profile)
}



#' plot_meth_profile
#'
#' Plot methylome profile for a gene.
#'
#' @param meth_profile a list of dmProfile
#' @param alpha.f a numeric specifying transparency of convolved signal.
#' @param ylim plot function parameter.
#' @param ... args pass to plot
#' @importFrom graphics lines
#' @importFrom graphics plot
#' @importFrom graphics matplot
#' @importFrom grDevices adjustcolor
#'
#'@export
plot_meth_profile = function(meth_profile, alpha.f, ylim=c(-1,1), ...){
  plot(meth_profile$x, meth_profile$y, ylim=ylim, type="l", ...)
  lines(meth_profile$x, meth_profile$mask, col=2)
  lines(meth_profile$x, meth_profile$y + 2* sqrt(meth_profile$var), lty=2)
  lines(meth_profile$x, meth_profile$y - 2* sqrt(meth_profile$var), lty=2)  
  if (missing(alpha.f)) {
    alpha.f=2/(ncol(meth_profile)-5)
  }
  matplot(meth_profile$x, meth_profile[,5:ncol(meth_profile)], col=adjustcolor(1, alpha.f=alpha.f), type="l", lty=1, lwd=3, add=TRUE)
}








#'dmDistance
#'
#'Perform either a frechet distance from the kmlShape package or the eucliddean distance modified from this package (default) between two dmProfile. Return a distance matrix.
#'[warning]Carefully use the frechet distance as it can be heavy computing when dealing with large set of profile. Complexity of the profile also weight on the memory usage. 
#'
#'@param profiles a list of dmProfile 
#'@param frechet a boolean specify if frechet distance will be computed.
#'
#'
#'@export
dmDistance <- function(profiles, frechet = FALSE){
  m  = sapply(profiles, "[[","y")
  v  = sapply(profiles, "[[","var")
  k  = sapply(profiles, "[[","mask")

  d = matrix(0, nrow=ncol(m), ncol=ncol(m) )
  for (i in 1:(ncol(m)-1)) {
    print(i)
    for (j in (i+1):ncol(m)) {
      euc = (m[,i] - m[,j])^2 / (v[,i] + v[,j])
      idx = k[,i] & k[,j] & !is.na(euc)
      # res = sum(euc * k[,i] * k[,j], na.rm=TRUE) / sum(k[,i] * k[,j], na.rm=TRUE)
      # res = sum(euc[idx] * k[idx,i] * k[idx,j]) / sum(k[idx,i] * k[idx,j])
      res = sum(euc[idx] * k[idx,i] * k[idx,j]) / sum(idx)
      res = sqrt(res)
        if (sum(idx)==0) {
          res = NA
        }
      d[i,j] = res
      d[j,i] = res
    }
  }
  
  return(d)
}



# #'dmDistance2
# #'
# #'Perform either a frechet distance from the kmlShape package or the eucliddean distance modified from this package (default) between two dmProfile. Return a distance matrix.
# #'[warning]Carefully use the frechet distance as it can be heavy computing when dealing with large set of profile. Complexity of the profile also weight on the memory usage.
# #'
# #'@param profiles a list of dmProfile
# #'@param frechet a boolean specify if frechet distance will be computed.
# #'
# #'
# #'@export
# dmDistance2 <- function(profiles, frechet = FALSE){
#   m  = sapply(profiles, "[[","y")
#   v  = sapply(profiles, "[[","var")
#   k  = sapply(profiles, "[[","mask")
#
#   d = sapply(1:ncol(m), function(i) {
#     print(i)
#     sapply(1:ncol(m), function(j) {
#       if (i>=j) {
#         return(0)
#       } else {
#         euc = (m[,i] - m[,j])^2 / (v[,i] + v[,j])
#         idx = k[,i] & k[,j] & !is.na(euc)
#         # res = sum(euc * k[,i] * k[,j], na.rm=TRUE) / sum(k[,i] * k[,j], na.rm=TRUE)
#         # res = sum(euc[idx] * k[idx,i] * k[idx,j]) / sum(k[idx,i] * k[idx,j])
#         res = sum(euc[idx] * k[idx,i] * k[idx,j]) / sum(idx)
#         res = sqrt(res)
#         # d[i,j] = res
#         # d[j,i] = res
#         if (sum(idx)==0) {
#           res = Inf
#         }
#         return(res)
#       }
#     })
#   })
#   d = d+t(d)
#
#   return(d)
# }





#'dmTable
#'
#'Generate differential methylation data table from beta values. It basically extract all tumorous samples and controls. Then it computes the difference between each tumorous and the mean of control.
#'
#'@param data A matrix of row methylation data with TCGA sample ids as column names and probes ids as row names.
#'@param tumoral_ref a vector of ids corresmasking to tumoral samples.
#'@param control_ref a vector of ids corresmasking to control samples.
#'
#'
#'@export
dmTable <- function(data, tumoral_ref, control_ref) {
  meanControl <- rowMeans(data[, control_ref], na.rm = TRUE)
  data    <- data[, tumoral_ref]
  AllDM = data - meanControl  
  return(AllDM)
}







#
# #'dmDistance_translocate
# #'
# #'Produce a list of two matrix : The distance matrix from a list of dmProfile. Each profile is translocated N times against another, we then keep the min(distance) in the matrix. The second matrix indicates which translocation returned the min(distance)
# #'
# #'@param dmprofileList a list of dmProfile
# #'@param updwn_str is the width of the window on the chromosome in bp where the function will fetch probes position and differential methylation value, default is 5000.
# #'@param slide is the maximum width slide you'll alow when comparing two curve, default is 0.
# #'@param by.interp is resolution at which the function interpolate the probes signal, default is 20.
# #'
# #'@export
# dmDistance_translocate <- function(dmprofileList, updwn_str=5000, slide=500, by.interp = 20){
#
#   #transform bp in bins of bp.length = by.interp
#   bwin   <- updwn_str / by.interp
#   bslide <- slide / by.interp
#
#   #create empty matrix
#   m  <- matrix(rep(NA, length(dmprofileList)*length(dmprofileList)), nrow = length(dmprofileList), ncol = length(dmprofileList))
#   mK <- matrix(rep(NA, length(dmprofileList)*length(dmprofileList)), nrow = length(dmprofileList), ncol = length(dmprofileList))
#
#   for(i in 1:(length(dmprofileList))){
#
#     m1 <- dmprofileList[[i]]
#
#     listmi <- translocateProfile(m1, bslide, bwin)
#
#     # return(listmi)
#     # for(j in (1+i):length(dmprofileList)){
#     for(j in 1:length(dmprofileList)){
#
#       m2 <- dmprofileList[[j]]
#       m2 <- m2[(1+bslide):(bwin*2+bslide), ]
#
#       #str(listmi)
#       distvect <- sapply(listmi, eucli_dist, m2=m2)
#       distvect <- sqrt(distvect)
#
#
#       if(all(is.nan(distvect))){
#         m[i,j]    <- NaN
#         mK[i,j]   <- NaN
#       }else{
#         #distvect[k+slide+1]  <- sqrt(eucli.dist(m1, m2))
#         m[i,j]    <- min(distvect, na.rm = TRUE)
#         distvect[is.nan(distvect)] <- max(distvect, na.rm = TRUE)
#         mK[i,j]   <- which.min(distvect) - bslide - 1
#         # print(which.min(distvect))
#       }
#
#     }
#   }
#   # dbmatrix <- list(dist=m, slide=mK)
#   dbmatrix <-list(m = m, mK = mK)
#   return(dbmatrix)
# }








# #'clustdmProfile
# #'
# #'Plot a dendrogram from a distance matrix, select cluster by clicks on the graphical window, click finish to get a list of geneNames in each cluster selected.
# #'
# #'Carefull, the function has been generating errors with less than 20 genes in the distance matrix.
# #'
# #'@param mat a distance Matrix
# #'@param fill_NA boolean specifying if NA should be imputed, need to be kept TRUE for now if there are NA in the matrix
# #'@param geneLabels A vector of genes names or id, can be extracted from a list of dmProfile with getProfileId
# #'
# #'@return A list of 2 object, the hclust result and a list containing the name of genes for each vector
# #'
# #'@export
# clustdmProfile <- function(mat, fill_NA = TRUE, geneLabels){
#
#   if(fill_NA){
#     for(i in 1:ncol(mat)){
#       mat[is.na(mat[,i]), i] <- mean(c(mean(mat[,i], na.rm = TRUE),
#                                        mean(mat[i,], na.rm = TRUE)))
#     }
#   }
#
#
#   colnames(mat) <- geneLabels
#   rownames(mat) <- geneLabels
#
#
#   hclust_result <- stats::hclust(stats::as.dist(mat), method = "complete")
#
#   graphics::plot(hclust_result)
#
#   print("Plot ready for cluster selection...")
#
#   list_clust <- graphics::identify(hclust_result)
#
#   print("Selection over")
#
#   clust_res <- list(hclust_result = hclust_result, genes_clust = list_clust)
#'
#   return(clust_res)
#
# }




#
# #'translocateProfile
# #'
# #'Produce a list of length bslide + 1 where each element is a dmProfile dataframe translocated around the tss
# #'
# #'@param m1 is a dmProfile dataframe to translocate using bslide
# #'@param bslide is the slide value divided by the width of each bin in dmProfile (= by.interp)
# #'@param bwin is the window parameter divided by the width of each bin in dmProfile (= by.interp)
# #'
# #'@export
# translocateProfile <- function(m1, bslide, bwin){
#
#   listmi <- list()
#
#   for (k in -bslide:bslide){
#
#     listmi[[k+bslide+1]]  <- m1[(1+bslide+k):(bslide+2*bwin+k), ]
#
#   }
#
#   return(listmi)
# }