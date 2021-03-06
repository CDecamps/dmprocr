#'getProfileListID
#'
#'Get a vector of Gene names from a list of dmProfile
#'
#'@param dmprofileList a list of dmProfile
#'
#'@return This function return a vector of gene names.
#'
#'
#'@export
getProfileListID <- function(dmprofileList){
  
  geneIds <- sapply(dmprofileList, function(x){x$id[[1]]})
  
  return(as.vector(geneIds))  
  
}