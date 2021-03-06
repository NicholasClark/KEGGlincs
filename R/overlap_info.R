#' Get overlap information for pairs of gene knock-outs from LINCS data
#' @export
#' @importFrom utils combn data
#' @import hgu133a.db
#' @import KOdata
#' @param KGML_file An object of formal class KEGGPathway
#' @param KEGG_mappings The data.frame object generated by the function 
#' expand_KEGG_mappings
#' @param cell_type Choose from the set of cell lines: 
#' (A375,A549,ASC,HA1E,HCC515,HEK293T,HEKTE,HEPG2,HT29,MCF7,NCIH716,NPC,PC3,
#' SHSY5Y,SKL,SW480,VCAP) 
#' @param data_type Choose from data types: (100_full, 100_bing, 50_lm)
#' @param pert_time Choose from (6,24,48,96,120,144,168)
#' @param only_mapped A logical indicator; if set to FALSE will return 'de-novo'
#' edges that 'exist' in data but are not documented in KEGG
#' @param affy_based A logical indicator; if set to TRUE will return 
#' lists/counts based on probeID instead of gene symbol.
#' @param keep_counts_only A logical indicator; if set to FALSE will return 
#' data frame with lists [of gene symbols or probe ids] as well as counts
#' @param add_fisher_information A logical indicator; by default the 
#' relationships are analyzed for strength of correlation via 
#' Fisher's Exact Test
#' @param p.adjust.method For available methods, type 'p.adjust.methods' into 
#' command promt and press enter.
#' @return A data frame where each row corresponds to information for pairs of 
#' experimental gene knock-outs from LINCS data (found in selected pathway).   
#' @examples 
#' p53_KGML <- get_KGML("hsa04115")
#' p53_KEGG_mappings <-  expand_KEGG_mappings(p53_KGML)
#' p53_edges <- expand_KEGG_edges(p53_KGML, p53_KEGG_mappings)
#' 
#' summary <- path_genes_by_cell_type(p53_KEGG_mappings)
#' p53_HA1E_data <- overlap_info(p53_KGML, p53_KEGG_mappings, 
#'                                "HA1E", data_type = "100_bing", 
#'                                only_mapped = FALSE)

overlap_info <- 
    function(KGML_file, KEGG_mappings, cell_type, 
                        data_type = "100_full",pert_time = 96,
                        only_mapped = TRUE, affy_based = FALSE,
                        keep_counts_only = TRUE, 
                        add_fisher_information = TRUE, 
                        p.adjust.method = "BH"){
    data("KO_data", envir = environment())
    KO_data <- get("KO_data")
    if(!cell_type %in% unique(KO_data$cell_id)){
        warning("Knock-out data is not available for selected cell-line \n")
        overlaps <- data.frame("null" = NA)
        return(overlaps)
        }
    KO_by_CT <- KO_data[KO_data$pert_time == pert_time & 
                        KO_data$cell_id == cell_type,]
    expanded_edges <- expand_KEGG_edges(KGML_file, KEGG_mappings)
    keeps <- c("entry1symbol", "entry2symbol")
    expanded_edges <- expanded_edges[expanded_edges$type != "maplink",keeps]
    if(nrow(expanded_edges) == 0 & only_mapped){
        warning("No documented edges are found in data; 
            only data for de-novo edges can be generated \n")
        overlaps <- data.frame("null" = NA)
        return(overlaps)
    }

    keeps <- c("entryACCESSION", "entrySYMBOL")
    path_genes <- KEGG_mappings[KEGG_mappings$entryTYPE == "gene", keeps]
    names(path_genes)[2] <- "SYMBOL"
    path_genes <- data.frame("ENTREZID" = unlist(path_genes$entryACCESSION), 
                            "SYMBOL" = unlist(path_genes$SYMBOL), 
                            stringsAsFactors = FALSE)
    path_genes <- path_genes[!duplicated(path_genes$ENTREZID),]
    data <- subset(path_genes, path_genes$SYMBOL %in% KO_by_CT$pert_desc)

    cat(paste0("Number of genes documented in selected pathway = ", 
                nrow(path_genes)), "\n")
    cat(paste0("Number of pathway genes in dataset = ", nrow(data),"\n"))
    cat(paste0("Coverage = ", round(nrow(data)/nrow(path_genes),4)*100,
                "%","\n"))
    if(nrow(data) == 0 | nrow(data) == 1){
        warning("Overlap data for selected pathway cannot be generated for 
            selected cell line")
        overlaps <- data.frame("null" = NA)
        return(overlaps)
    }

    conversion_key <- suppressMessages(
        AnnotationDbi::select(hgu133a.db::hgu133a.db, 
        AnnotationDbi::keys(hgu133a.db), c("SYMBOL","ENTREZID"), "PROBEID"))
  
    for (i in 1:nrow(data)){
        if (data_type == "100_full"){
            data$up[i] <- 
                strsplit(KO_by_CT$up100_full[KO_by_CT$pert_desc == 
                                                data$SYMBOL[i]], ";")
            data$down[i] <- 
                strsplit(KO_by_CT$dn100_full[KO_by_CT$pert_desc == 
                                                data$SYMBOL[i]], ";")
        }
        else if (data_type == "100_bing"){
            data$up[i] <- 
                strsplit(KO_by_CT$up100_bing[KO_by_CT$pert_desc == 
                                                data$SYMBOL[i]], ";")
            data$down[i] <- 
                strsplit(KO_by_CT$dn100_bing[KO_by_CT$pert_desc == 
                                                data$SYMBOL[i]], ";")
        }
        else if (data_type == "50_lm"){
            data$up[i] <- 
                strsplit(KO_by_CT$up50_lm[KO_by_CT$pert_desc == 
                                            data$SYMBOL[i]], ";")
            data$down[i] <- 
                strsplit(KO_by_CT$dn50_lm[KO_by_CT$pert_desc == 
                                            data$SYMBOL[i]], ";")
        }
        else {
            warning("valid data_type options: 100_full, 100_bing, 50_lm")
            return(NA)
        }
        data$up_symbol[i] <- 
            list(conversion_key$SYMBOL[which(conversion_key$PROBEID %in% 
                                            unlist(data$up[i]))])
        data$down_symbol[i] <-
            list(conversion_key$SYMBOL[which(conversion_key$PROBEID %in% 
                                            unlist(data$down[i]))])
    }
    overlaps<- data.frame(t(combn(data$SYMBOL,2)), stringsAsFactors = FALSE)
    names(overlaps) <- c("knockout1", "knockout2")
    overlaps$unique_ID <- paste0(overlaps$knockout1, ",", overlaps$knockout2)
    expanded_edges$unique_ID <- paste0(expanded_edges$entry1symbol, ",", 
                                    expanded_edges$entry2symbol)
    expanded_edges$unique_IDR <- paste0(expanded_edges$entry2symbol, ",", 
                                    expanded_edges$entry1symbol)
    pre_mapped1 <- subset(overlaps, overlaps$unique_ID %in% 
                        expanded_edges$unique_ID) ## Direction is correct
    pre_mapped2 <- subset(overlaps, overlaps$unique_ID %in% 
                        expanded_edges$unique_IDR) ## Direction is reversed
    pre_mapped2 <- pre_mapped2[,c(2,1)]
    names(pre_mapped2)[c(1,2)] = names(pre_mapped1)[c(1,2)]
    if(nrow(pre_mapped2) >= 1 & nrow(pre_mapped1) >= 1){
        pre_mapped2$unique_ID <- paste0(pre_mapped2$knockout1, ",", 
                                    pre_mapped2$knockout2)
        pre_mapped <- rbind(pre_mapped1, pre_mapped2)
    }
    if (nrow(pre_mapped2) == 0 & (nrow(pre_mapped1) == 0)){
        pre_mapped <- data.frame("unique_ID" = NA)
    }
    if (nrow(pre_mapped1) == 0 & nrow(pre_mapped2) >= 1){
        pre_mapped2$unique_ID <- paste0(pre_mapped2$knockout1, ",", 
                                    pre_mapped2$knockout2)
        pre_mapped <- pre_mapped2
    }
    if (nrow(pre_mapped2) == 0 & nrow(pre_mapped1) >= 1){
        pre_mapped <- pre_mapped1
    }
    if(is.na(pre_mapped[1,1]) & only_mapped){
        warning("No documented edges are found in data; only data for 
                de-novo edges can be generated \n")
        overlaps <- data.frame("null" = NA)
        return(overlaps)
    }
    pre_mapped$pre_mapped <- 1
    keeps <-c("knockout1", "knockout2", "pre_mapped")
    pre_mapped <- pre_mapped[,keeps]
    if (!only_mapped){
        un_mapped <- subset(overlaps, !overlaps$unique_ID %in% 
                        expanded_edges$unique_ID & !overlaps$unique_ID %in% 
                        expanded_edges$unique_IDR)
        un_mapped$pre_mapped <- 0
        un_mapped <- un_mapped[,keeps]
        overlaps <- rbind(pre_mapped, un_mapped)
    }
    else {
        overlaps <- pre_mapped
    }
    for (i in 1:nrow(overlaps)){
        overlaps$affy.genesUP[i] <- 
            list(intersect(unlist(data$up[which(data$SYMBOL == overlaps[i,1])]),
                        unlist(data$up[which(data$SYMBOL == overlaps[i,2])])))
    overlaps$affy.genesDOWN[i] <- 
        list(intersect(unlist(data$down[which(data$SYMBOL == overlaps[i,1])]), 
                        unlist(data$down[which(data$SYMBOL == overlaps[i,2])])))
    overlaps$affy.genesUPK1_DOWNK2[i] <- 
        list(intersect(unlist(data$up[which(data$SYMBOL == overlaps[i,1])]), 
                        unlist(data$down[which(data$SYMBOL == overlaps[i,2])])))
    overlaps$affy.genesDOWNK1_UPK2[i] <- 
        list(intersect(unlist(data$down[which(data$SYMBOL == overlaps[i,1])]), 
                        unlist(data$up[which(data$SYMBOL == overlaps[i,2])])))
    overlaps$num.affy.genesUP[i] <- length(unlist(overlaps$affy.genesUP[i]))
    overlaps$num.affy.genesDOWN[i] <- length(unlist(overlaps$affy.genesDOWN[i]))
    overlaps$num.affy.genesUPK1_DOWNK2[i] <- 
        length(unlist(overlaps$affy.genesUPK1_DOWNK2[i]))
    overlaps$num.affy.genesDOWNK1_UPK2[i] <- 
        length(unlist(overlaps$affy.genesDOWNK1_UPK2[i]))
    }
    if (!affy_based){
        for(i in 1:nrow(overlaps)){
            overlaps$genes.symbolsUP[i]<- 
                list(conversion_key$SYMBOL[which(conversion_key$PROBEID %in% 
                                        unlist(overlaps$affy.genesUP[i]))])
            overlaps$genes.symbolsDOWN[i]<- 
                list(conversion_key$SYMBOL[which(conversion_key$PROBEID %in% 
                                        unlist(overlaps$affy.genesDOWN[i]))])
        overlaps$genes.symbolsUPK1_DOWNK2[i]<- 
            list(conversion_key$SYMBOL[which(conversion_key$PROBEID %in% 
                                unlist(overlaps$affy.genesUPK1_DOWNK2[i]))])
        overlaps$genes.symbolsDOWNK1_UPK2[i]<- 
            list(conversion_key$SYMBOL[which(conversion_key$PROBEID %in% 
                                unlist(overlaps$affy.genesDOWNK1_UPK2[i]))])
        overlaps$num.genes.symbolsUP[i] <- 
            length(unlist(overlaps$genes.symbolsUP[i]))
        overlaps$num.genes.symbolsDOWN[i] <- 
            length(unlist(overlaps$genes.symbolsDOWN[i]))
        overlaps$num.genes.symbolsUPK1_DOWNK2[i] <- 
            length(unlist(overlaps$genes.symbolsUPK1_DOWNK2[i]))
        overlaps$num.genes.symbolsDOWNK1_UPK2[i] <- 
            length(unlist(overlaps$genes.symbolsDOWNK1_UPK2[i]))
        }
        keeps = c("knockout1","knockout2","num.genes.symbolsUP", 
                    "num.genes.symbolsDOWN", "num.genes.symbolsUPK1_DOWNK2", 
                    "num.genes.symbolsDOWNK1_UPK2", "genes.symbolsUP", 
                    "genes.symbolsDOWN", "genes.symbolsUPK1_DOWNK2", 
                    "genes.symbolsDOWNK1_UPK2", "pre_mapped")
        overlaps <- overlaps[,keeps]
    }
    else {
        keeps = c("knockout1","knockout2","num.affy.genesUP", 
                "num.affy.genesDOWN", "num.affy.genesUPK1_DOWNK2", 
                "num.affy.genesDOWNK1_UPK2", "affy.genesUP", "affy.genesDOWN", 
                "affy.genesUPK1_DOWNK2", "affy.genesDOWNK1_UPK2", "pre_mapped")
        overlaps <- overlaps[, keeps]
    }
    names(overlaps)[c(3:6)] <- c("UP", "DOWN", "UK1_DK2", "DK1_UK2")
    method = p.adjust.method
    if (keep_counts_only){
        keeps = c("knockout1","knockout2", "UP", "DOWN", "UK1_DK2", "DK1_UK2", 
                "pre_mapped")
        overlaps <- overlaps[,keeps]
        }
    if(add_fisher_information){
        overlaps <- get_fisher_info(overlaps, method)
    }
    return(overlaps)
}