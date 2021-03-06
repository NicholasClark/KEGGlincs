% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_KGML.R
\name{get_KGML}
\alias{get_KGML}
\title{Download and parse KGML file}
\usage{
get_KGML(pathwayid, get_if_no_edges = FALSE)
}
\arguments{
\item{pathwayid}{A KEGG pathway ID of the form "hsa12345" 
(only human pathways currently)}

\item{get_if_no_edges}{A logical indicator; if pathway has no edges 
returns null value if set to TRUE}
}
\value{
an object of Formal class KEGGPathway
}
\description{
Download and parse KGML file
}
\examples{
mtor_KGML <- get_KGML("hsa04150")

# Some pathways contain only node information; since the purpose of this
# package is to explore pathways in an edge-focused manner, the default
# options return a warning message instead of a parsed KGML file if the 
# input pathway has no edges.
ribosome_KGML <- get_KGML("hsa03020") 
ribosome_KGML <- get_KGML("hsa03020", get_if_no_edges = TRUE) 

}
