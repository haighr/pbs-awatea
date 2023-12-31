setClass ("AWATEAdata", 
     representation( txtnam="character", input="character", vlst="list", 
     dnam="character", nvars="numeric", vdesc="character", vars="list", 
     gcomm="character", vcomm="character", resdat="list" , likdat="list",
     pardat="list", stddat="list", cordat="list", evadat="list", 
     reweight="list", controls="list") )

#require(PBSmodelling)
#source("utilFuns.r",local=FALSE)

#runADMB--------------------------------2019-04-04
# Run AD Model Builder code for Awatea
#-----------------------------------------------RH
runADMB = function(
   filename.ext, wd=getwd(), strSpp="XYZ",
   runNo=1, rwtNo=0,
   doMPD=FALSE,
   N.reweight = 1,  ## number of reweight iterations
   A.reweight = 1,  ## abundance reweight method 0=no reweight, 1=add pocess error, 2=SDNR
   C.reweight = 1,  ## composition reweight method: 0=no reweight, 1=Francis (2011) mean age, 2=SDNR
   cvpro      = 0,  ## if Ncpue>0 then cvpro lists cvpro for CPUE after those for surveys
   doMCMC=FALSE, 
   mcmc=1e6, mcsave=1e3, ADargs=NULL, verbose=FALSE, 
   doMSY=FALSE, 
   msyMaxIter=15000., msyTolConv=0.01, endStrat=0.301, stepStrat=0.001,
   delim="-", clean=FALSE, locode=FALSE, 
   awateaPath="C:/Users/haighr/Files/Projects/ADMB/Coleraine",
   codePath="C:/Users/haighr/Files/Projects/R/Develop/PBSawatea/Authors/Rcode/develop",
   ...)
{
	ciao = function(){setwd(cwd); Sys.setenv(PATH=syspath0); gc(verbose=FALSE)} # exit function
	cwd  = getwd(); syspath0  = Sys.getenv()["PATH"]
	on.exit(ciao())
	if (!doMPD)
		cvpro = tcall(PBSawatea)$cvpro  ## retain cvpro from initially run MPD
	if (locode) { 
		#ici = sys.frame(sys.nframe())
		#load(paste0(system.file("data",package="PBSawatea"),"/gfcode.rda"), envir=ici)
#browser();return()
		eval(parse(text="require(PBSmodelling, quietly=TRUE, warn.conflicts=FALSE)"))
		source(paste(codePath,"PBSscape.r",sep="/"),local=FALSE)
		source(paste(codePath,"runSweave.r",sep="/"),local=FALSE)
		source(paste(codePath,"runSweaveMCMC.r",sep="/"),local=FALSE)
		source(paste(codePath,"plotFuns.r",sep="/"),local=FALSE)
		source(paste(codePath,"utilFuns.r",sep="/"),local=FALSE)
		source(paste(codePath,"menuFuns.r",sep="/"),local=FALSE)
		#do.call("assign", args=list(x="importCol2", value=importRes, envir=.GlobalEnv)) # RH: removed importCol2 (2013-09-13)
	}
	awateaPath = gsub("/","\\\\",awateaPath)
	syspath   = paste(syspath0,awateaPath,sep=";")
	Sys.setenv(PATH=syspath)
	# Be careful when using this that it doesn't destroy files other than those from Awatea
	if (clean) {
		junkpat = c("^[Aa]watea","^admodel","\\.log$","\\.pst$","\\.out$","\\.rpt$","\\.tmp$","^variance$","^results.dat$","^likelihood.dat$")
		junkit  = sapply(junkpat,function(x){list.files(pattern=x)})
		junkit  = sapply(junkit,setdiff,"Awatea.exe")
		junk    = sapply(junkit,function(x){ if (length(x)>0) for (i in x) if (file.exists(i)) file.remove(i)})
	}
	runNoStr = pad0(runNo,2)
	runname  = paste(strSpp,"run",runNoStr,sep="")
	rundir   = paste(wd,runname,sep="/")
	#if (file.exists("results.dat")) file.remove("results.dat")
	ext      = sapply(strsplit(filename.ext,"\\."),tail,1)
	prefix   = substring(filename.ext,1,nchar(filename.ext)-nchar(ext)-1)
	prun     = regexpr(runNoStr,prefix)
	if (!(prun>0 && attributes(prun)$match.length==nchar(runNoStr))) {
		if (!getYes("Input file appears mismatched with Run specified. Continue?"))
			stop("Resolve run number with name of input file")
	}
	prefix   = gsub(paste(delim,runNoStr,sep=""),"",prefix)  # get rid of superfluous run number in name
	prefix = gsub(runNoStr,"",prefix)                        # get rid of superfluous run number in name
	argsMPD = argsMCMC = NULL
	if (!is.null(ADargs)) {
		if(!is.list(ADargs)) stop("'ADargs' must be either a list or NULL")
		for (i in ADargs) {
			if (!grepl("mc",i))     argsMPD = c(argsMPD,list(i)) 
			if (!grepl("nohess",i) & !grepl("mcmc",i) & !grepl("mcsave",i)) argsMCMC = c(argsMCMC,list(i)) 
		}
	}
	argsMPD  = paste(paste(" ",unlist(argsMPD),sep=""),collapse="")
	argsMCMC = paste(paste(" ",unlist(argsMCMC),sep=""),collapse="")
	packList(stuff=c("awateaPath","codePath","wd","filename.ext","strSpp","runNo","N.reweight","cvpro","runname","rundir"), target="PBSawatea")

	if (doMPD) {
		if (!file.exists(filename.ext))
			stop("Specified input file does not exist")
		.flash.cat(paste0("\nRunning MPD on ", filename.ext, "...\n"))
		file.controls = readAD(filename.ext)@controls
#browser();return()
		Ncpue    = file.controls$Ncpue
		Nsurv    = file.controls$Nsurv
		cvpro    = file.controls$cvpro # expanded cvpro determined by number of surveys and number of cpue series
		sdnrfile = paste(prefix,runNoStr,"sdnr",sep=".")
		#cat("#SDNR (Surveys, CPUE, CAs, CAc)\n",file=sdnrfile)
		header   = paste0("## SDNR -- ", ifelse(Nsurv>0,paste0("Surveys(",Nsurv,"), "),""), ifelse(Ncpue>0,paste0("CPUE(",Ncpue,"), "),""), "CAsurv, CAcomm, devSDNR\n## wj   -- AF(comm), AF(surv)\n")  ## RH 200417
#browser();return()
		cat(header,file=sdnrfile)
		cat("CVpro:",cvpro,"\n",file=sdnrfile,append=TRUE,sep=" ")
		#file0 = gsub(paste("\\.",ext,sep=""),paste(".000.",ext,sep=""),filename.ext)
		file0 = paste(prefix,runNoStr,"00.txt",sep=".")
		fileX = c("likelihood.dat",paste("Awatea",c("par","std","cor","eva"),sep=".")) ## extra files to save
		fileA = character(0) # All accumulated files
		#suffix = c("par","std","cor") # extra files to save
#browser();return()

		## New concept on reweighting (RH 1904043) -- treat reweighting of abundance (A) and composition (C) separate
		A.reweight = rep(A.reweight,N.reweight)[1:N.reweight]
		C.reweight = rep(C.reweight,N.reweight)[1:N.reweight]

		for (i in 0:N.reweight) {
			ii = pad0(i,2)

			## Either start with initial file or apply reweights to previous file
			if (i==0) {
				fileN = file0
				file.copy(from=filename.ext,to=file0,overwrite=TRUE)
			} else {
				desc = Robj@vdesc; dat = Robj@vars; newdat=Robj@reweight
				## Collect pointers to abundance and composition data to populate with re-weighted values
				rvar1 = names(findPat("Survey abundance indices",desc))
				rvar2 = names(findPat("CPUE \\(Index",desc))
				rvar3 = names(findPat("Commercial catch at age data",desc))
				rvar4 = names(findPat("Survey C@A data",desc))
				if (length(c(rvar1,rvar2,rvar3,rvar4))!=4)
					stop ("INPUT -- Someone has changed at least one header name for abundance/composition data !!!!")

				survey = dat[[rvar1]]; #dimnames(index) = list(1:nrow(index),c("series","year","obs","CV"))
				survey[,4] = newdat$survey$CVnew
				cpue = dat[[rvar2]]
				if (!is.null(newdat$cpue))
					cpue[,5] = newdat$cpue$CVnew
				CAc = dat[[rvar3]]
				if (is.vector(CAc)) CAc = makeRmat(CAc,rowname=names(newdat$wNcpa))
				CAc[,3] = newdat$wNcpa  ## No. of commercial age samples
#browser();return()
				CAs = dat[[rvar4]]
				if (is.vector(CAs)) CAs = makeRmat(CAs,rowname=names(newdat$wNspa))
				CAs[,3] = newdat$wNspa  ## No. of survey age samples

				Robjnew = fix(Robj,c(rvar1,rvar2,rvar3,rvar4),list(survey,cpue,CAc,CAs))
				#hh=pad0(i-1,3); fileN = gsub(hh,ii,fileN)
				fileN = paste(prefix,runNoStr,ii,"txt",sep=".")
				write(Robjnew,fileN)
			}

			## Run the MPD
			if (i==0)
				.flash.cat("\nProcessing initial MPD fit without reweighting...\n")
			else 
				.flash.cat(paste0("\n","Processing MPD fit for Rwt ", i, "...\n"))
			expr=paste("mess = shell(cmd=\"awatea -ind ",fileN,argsMPD,"\", wait=TRUE, intern=TRUE)",sep="")
#browser();return()
			eval(parse(text=expr))
			if (verbose)  .flash.cat(mess, sep="\n")
			if (length(mess)<10) stop("Abnormal program termination")

			## Copy results of MPD
			fileR = gsub(paste("\\.",ext,"$",sep=""),".res",fileN)
			if (file.exists("results.dat"))
				file.copy("results.dat",fileR,overwrite=TRUE)
			else
				stop ("!!!!! No results file generated ('results.dat')")
			fileA = c(fileA,fileN,fileR)
			for (jfile in fileX){
				#jfile = paste("Awatea",j,sep=".")
				if (file.exists(jfile)){
					if (substring(jfile,1,6)=="Awatea")
						suffix  = sapply(strsplit(jfile,"\\."),tail,1)
					else if (jfile=="likelihood.dat") suffix = "lik"
					else suffix = "tmp"
					fileS = gsub(paste("\\.",ext,"$",sep=""),paste("\\.",suffix,sep=""),fileN)
					file.copy(jfile,fileS,overwrite=TRUE)
					fileA = c(fileA,fileS)
				}
			}

			## Reweight the input files until N.reweight-1
			if (i <= N.reweight) {
				inext = i + 1
				eval(parse(text=paste("Robj = readAD(\"",fileN,"\")",sep="")))
#browser();return()
				if (i < N.reweight) {
					.flash.cat("\nReweighting abundance (surveys) and composition (proportions-at-age)...\n")
					Robj@reweight = list(nrwt=inext)
					Robj = reweight(Robj, A.rwt=A.reweight[inext], C.rwt=C.reweight[inext], cvpro=cvpro, sfile=sdnrfile, fileN=fileN)
				} else {
					## Send an artificial reweight to get SDNRs for the final reweight
					Robj@reweight = list(nrwt=0)
					dummy = reweight(Robj, A.rwt=0, C.rwt=0, cvpro=cvpro, sfile=sdnrfile, fileN=fileN)
				}
			}
			#Robj = reweight(Robj, cvpro=cvpro, mean.age=mean.age, sfile=sdnrfile, fileN=fileN) ## old call
		} ## end reweight loop

		if (!file.exists(rundir)) dir.create(rundir)
		#fileA = paste(prefix,runNoStr,rep(pad0(0:N.reweight,2),each=length(suffix)+2),rep(c(ext,"res",suffix),N.reweight+1),sep=".")
		file.copy(paste(wd,c(filename.ext,fileA,sdnrfile),sep="/"),rundir,overwrite=TRUE)
		file.remove(paste(wd,c(fileA,sdnrfile),sep="/"))
	}
	if (doMCMC | doMSY) {
		rwtNoStr = pad0(rwtNo,2)
		fileN    = paste(prefix,runNoStr,rwtNoStr,ext,sep=".")
		mcname   = paste("MCMC",runNoStr,rwtNoStr,sep=".")
	}
	if (doMCMC) {
		.flash.cat(paste("Running",mcmc,"MCMC iterations...\n"))
		mcdir    = paste(wd,runname,mcname,sep="/")
		if (!file.exists(mcdir)) dir.create(mcdir)
		fileA = paste(prefix,runNoStr,rwtNoStr,c(ext,"res"),sep=".")
		file.copy(paste(rundir,fileA,sep="/"),mcdir,overwrite=TRUE); setwd(mcdir)
		expr=paste("shell(cmd=\"awatea -ind ",fileN," -mceval\" , wait=TRUE, intern=FALSE)",sep="")
		.flash.cat(expr, sep="\n")
		eval(parse(text=expr))
		
		Robj="dummy4now"
	}
	if (doMSY) {
		.flash.cat(paste("Running MSY yield calculations...\n"))
		msyname  = paste("MSY",runNoStr,rwtNoStr,sep=".")
		msydir   = paste(wd,runname,mcname,msyname,sep="/")
		if (!file.exists(msydir)) dir.create(msydir)
		fileN = paste(prefix,runNoStr,rwtNoStr,ext,sep=".")
		fileA = c(paste(wd,runname,mcname,fileN,sep="/"),paste(wd,runname,mcname,"Awatea.psv",sep="/")) ## RH 200416
#browser();return()
		file.copy(fileA,msydir,overwrite=TRUE); setwd(msydir)
		ctlfile  = paste(c("#MSY control file",
			"#Maximum number of iterations",format(msyMaxIter,scientific=FALSE),
			"#Tolerance for convergence",format(msyTolConv,scientific=FALSE) ), collapse="\n")
		cat(ctlfile,"\n",sep="",file="Yields.ctl")

		infile = readAD(fileN)
		strategy = view(infile,pat=c("Strategy","End year"),see=FALSE)
		## Reset the strategy and express in terms of U
		strategy[[grep("Strategy Type",names(strategy))]] = 2
		strategy[[grep("End year of projections",names(strategy))]]  = -99
		strategy[[grep("End Strategy",names(strategy))]]  = endStrat
		strategy[[grep("Step Strategy",names(strategy))]] = stepStrat
		vnam = substring(names(strategy),1,4)
		infile = fix(infile,vnam,strategy) ## replace the contents of infile with updated strategy
		write(infile,fileN)                ## overwrite the input file for MSY calculations
		expr=paste("shell(cmd=\"awatea -ind ",fileN," -mceval\" , wait=TRUE, intern=FALSE)",sep="")
		.flash.cat(expr, sep="\n")
		eval(parse(text=expr))
		
		Robj=list(ctlfile,strategy)
	}
	if (exists(".PBSmodEnv")) packList(stuff=c("Robj"), target="PBSawatea")
	invisible(Robj)
}
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~runADMB


## readAD-------------------------------2013-09-09
## Read the ADMB input file and create an AWATEA class object.
## ---------------------------------------------RH
readAD = function(txt)
{
	txtnam = as.character(substitute(txt))
	otxt = readLines(txt) # original text
	utxt = otxt[!is.element(substring(otxt,1,3),"###")] ## use text (remove data not comments)
	xlst = strsplit(utxt,"")
	xlst = xlst[sapply(xlst,length)>0]
	ntxt = sapply(xlst,function(x){paste(clipVector(x,clip="\t",end=2),collapse="")})
	ntxt = gsub("\\\t\\\t","\t",ntxt)   ## internal cleanup
	vlst = list(); vcom=NULL; acom=NULL
	for (i in 1:length(ntxt)) {
		if (substring(ntxt[i],1,1)=="#") {
			expr = paste("vlst[[\"L",pad0(i,3),": Comment\"]] = ",deparse(ntxt[i],width.cutoff=500),sep="")
			comm = substring(ntxt[i],2,) ; names(comm)=i
			acom = c(acom,comm) }
		else {
			vcom = c(vcom,comm)
			expr = paste("vlst[[\"L",pad0(i,3),": Data {",comm,"}\"]] = c(",gsub("\\\t",",",ntxt[i]),")",sep="") }
		eval(parse(text=expr))
	}
	
	## description of variables with inputs
	vdesc = unique(vcom) 
	gcomm = acom[!is.element(acom,vdesc)] ## general comments
	vcomm = acom[is.element(acom,vdesc)]  ## variable comments (may be duplicated)
	nvars = length(vdesc)
	names(vdesc) = paste("v",pad0(1:nvars,3),sep="")
	vars = as.list(vdesc)

	dnam = names(vlst); names(dnam)=1:length(dnam)
	dnam = dnam[grep("Data",dnam)]
	dnam = substring(dnam,13,nchar(dnam)-1)
	
	for (i in names(vdesc)) {
		ivar = vlst[as.numeric(names(dnam[is.element(dnam,vdesc[i])]))]
		ilen = length(ivar)
		if (ilen==1) vars[[i]] = ivar[[1]]
		else if (ilen>=2) {
			jvar=NULL
			for (j in 1:length(ivar))
				jvar=rbind(jvar,ivar[[j]])
			vars[[i]] = jvar
		}
		else {browser();return()}
	}
	#writeList(vars,gsub("\\.txt",".pbs.txt",txtnam),format="P") ## write to a PBS formatted text file
	suffix = c("res","lik","par","std","cor","eva")
	for (j in suffix) {
		jnam = gsub("\\.txt$",paste(".",j,sep=""),txtnam)
		#do.call("assign", args=list(x=paste0(j,"nam"), value=jnam))
		if (!file.exists(jnam)) do.call("assign", args=list(x=paste0(j,"dat"), value=list()))
		else {
			if (j=="res") {
				resdat = importRes( res.file=jnam, Dev=TRUE, CPUE=TRUE, Survey=TRUE, CLc=FALSE, CLs=FALSE, CAs=TRUE, CAc=TRUE, extra=TRUE)
				attr(resdat,"class") = "list" }
			#else if (j=="par") pardat = importPar(par.file=jnam)
			#else if (j=="std") stddat = importStd(std.file=jnam)
			#else if (j=="cor") cordat = importCor(cor.file=jnam)
			else {
				mess = paste(j,"dat = import",toupper(substring(j,1,1)),substring(j,2,3),"(",j,".file=jnam)",sep="")
				eval(parse(text=mess))
			}
		}
	}
	## Gather some control variables from original text (otxt)
	## -------------------------------------------------------
	ctllabs=list(Nsex="Number of sexes", Nsurv="Number of survey series", Ncpue="Number of CPUE series",
	likeCPUE="CPUE likelihood Type",
	NsurvDP="Number of survey data points \\(all series\\)", NcpueDP="Number of CPUE data points \\(all series\\)",
	NyrCAs="Number of years with survey C@A data", NyrCAc="Number of years with commercial C@A data", 
	Nmethod="Number of commercial fishing gears", gear="Initial gear",
	ageMax="Max age in model", ageFullMat = "Age at full maturity",
	YrStart="Start year of model",YrEnd="End year of model",YrProj="End year of projections",
	strategy="Strategy Type", Usplit="Strategy U")

	controls=sapply(ctllabs,function(x){
		strval = gsub("#","",otxt[grep(x,otxt)[1]+1])
		# sometimes need to get rid of pesky tab characters
		strvec = strsplit(strval,"\t")[[1]]
		strvec = strvec[strvec!="" & !is.na(strvec)]
		as.numeric(strvec)
	},simplify=FALSE)

	if (all(controls$likeCPUE==0)) controls$Ncpue=0   # discount dummy CPUE data if likelihood type = 0
	cvpro = if (exists(".PBSmodEnv")) tcall(PBSawatea)$cvpro else PBSawatea$cvpro
	Nsc   = controls$Nsurv + controls$Ncpue      # Ncpue always at least 1, even if just dummy data (Awatea quirk)
	controls[["cvpro"]] = rep(cvpro,Nsc)[1:Nsc]  # expand cvpro to accommodate all series (user may only specify one value, or underestimate number of series)

	Data=new("AWATEAdata",txtnam=txtnam, input=ntxt, vlst=vlst, dnam=dnam, 
		nvars=nvars, vdesc=vdesc, vars=vars, gcomm=gcomm, vcomm=vcomm, resdat=resdat,
		likdat=likdat, pardat=pardat, stddat=stddat, cordat=cordat, evadat=evadat, 
		reweight=list(nrwt=0), controls=controls)
	return(Data)
}
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~readAD


## setMethod.view-----------------------2011-11-09
## Set the method for 'view' when using an AWATEA class.
## ---------------------------------------------RH
view = PBSmodelling::view
setMethod("view", signature(obj = "AWATEAdata"),
   function (obj, n=1:5, last=FALSE, random=FALSE, print.console=TRUE, see=TRUE, ...)
{
	dat = obj@vars; desc= obj@vdesc; nvars=obj@nvars
	dots = list(...)
	if (!is.null(dots$pat)) {
		patty = findPat(dots$pat,desc)
		if (length(patty)==0) stop("Specified pattern not found")
		else {
			seedat = dat[names(patty)]; names(seedat) = paste(names(patty),patty,sep=": ")
		}
	}
	else if (!last & !random) {
		seedat = dat[n]; names(seedat) = paste(names(desc[n]),desc[n],sep=": ") }
	else if (last) {
		seedat = dat[rev(nvars-n+1)]; names(seedat) = paste(names(desc[rev(nvars-n+1)]),desc[rev(nvars-n+1)],sep=": ") }
	else seedat="Random option not implemented for AWATEAdata class"
	if (see) print(seedat)
	else invisible(seedat)
	} )
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~setMethod.view


## setMethod.fix------------------------2011-05-31
## Set the method for 'fix' when using an AWATEA class.
## ---------------------------------------------RH
setMethod("fix", signature(x = "AWATEAdata"),
   function (x, varN, xnew, ...)
{
	dat = x@vars; desc=x@vdesc
	dots = list(...)
	nvar = length(varN)
	if (nvar>1 & !is.list(xnew) && length(xnew)!=nvar)
		stop("'xnew' must be a list of objects to match multiple 'varN'")
	for ( i in 1:nvar) {
		if (nvar==1 & !is.list(xnew)) oo = xnew
		else oo = xnew[[i]]
		dat[[varN[i]]] = oo
	}
	x@vars = dat
	return(x)
} )
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~setMethod.fix


## setMethod.write----------------------2011-05-31
## Set the method for 'write' when using an AWATEA class.
## ---------------------------------------------RH
setMethod("write", signature(x = "AWATEAdata"),
   function(x, file="something.txt", ncolumns = if(is.character(x)) 1 else 5,
   append = FALSE, sep = "\t")
{
	vlst=x@vlst; dnam=x@dnam; vdesc=x@vdesc; vars=x@vars; gcomm=x@gcomm; vcomm=x@vcomm
	olst = list()
	for (i in 1:length(vlst)) {
		ii = as.character(i); iii=as.character(i+1)
		if (is.element(ii,names(gcomm)))
			olst[[ii]] = paste("#",gcomm[ii],sep="")
		else if (is.element(ii,names(vcomm))) {
			olst[[ii]] = paste("#",vcomm[ii],sep="")
#if(i==50) {browser();return()}
			if (is.na(dnam[iii])) next  ## if variable header is duplicated and one is commented out
			olst[[iii]] = vars[[names(vdesc[is.element(vdesc,dnam[iii])])]]
		}
		else next
	}
	nlin = sum(sapply(olst,function(x){if(is.matrix(x)) nrow(x) else 1}))
	nvec = rep("",nlin)
	ii   = 0
	for (i in 1:length(olst)) {
		oo = olst[[i]]
		ii = ii + 1
		if (is.matrix(oo)) {
			for (j in 1:nrow(oo)) {
				ii = ii + ifelse(j==1,0,1)
				nvec[ii] = paste(oo[j,],collapse=sep)
			}
		}
		else if (is.numeric(oo)) 
			nvec[ii] = paste(oo,collapse=sep)
		else
			nvec[ii] = oo
	}
	writeLines(nvec,con=file)
	invisible(nvec) } )
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~setMethod.write


## setMethod.reweight-------------------2019-04-04
## Set the method for 'reweight' when using an AWATEA class.
## Calculates reweighted values and populates S4 object.
## ---------------------------------------------RH
#reweight <- function(obj, cvpro=FALSE, mean.age=TRUE, ...) return(obj) ## old function
reweight <- function(obj, A.rwt=1, C.rwt=1, cvpro=0, ...) return(obj)

setMethod("reweight", signature="AWATEAdata",
   #definition = function (obj, cvpro=FALSE,  mean.age=TRUE, ...) ## old method
   definition = function (obj, A.rwt=1, C.rwt=1, cvpro=0, ...)
{
	nrwt = obj@reweight$nrwt; 
	dat  = obj@vars; desc=obj@vdesc; res=obj@resdat
	dots = list(...)

	##===== start subfuns =====

	## Normal residual for an observation (Coleraine Excel algorithm only)
	## (F.26 POP 2010 assessment)
	NRfun  = function(O,P,CV,maxR=0,logN=TRUE)  {
		if (logN) {
			num = log(O) - log(P) + 0.5*log(1+CV^2)^2
			den = sqrt(log(1+CV^2))
			NR  = num/den }
		else
			NR = (O-P)/CV
		if (round(maxR,6)!=0) {
			maxR = c(-abs(maxR),abs(maxR))
			NR[NR < maxR[1]] = maxR[1]
			NR[NR > maxR[2]] = maxR[2] }
		return(NR)
	}

	## Standard deviaton of observed proportion-at-ages (Coleraine Excel algorithm only)
	## (F.27 POP 2010 assessment)
	SDfun = function(p,N,A) {
		# p = observed proportions, N = sample size, A = no. sexes times number of age bins
		SD = sqrt((p * (1-p) + 0.1/A) / N) 
		SD[!is.finite(SD)] = NA
		return(SD)
	}

	## Re-weighted (effective) N for porportions-at-age (Coleraine Excel algorithm only)
	eNfun = function(S,Y,O,P,Nmax=200) {
		# S = Series, Y = Year, O = Observed proportions, P = Predicted (fitted) proportions, Nmax = maximum sample size allowed
		f   = paste(S,Y,sep="-")
		num = sapply(split(P,f),function(x) { sum( x * (1 - x) ) } )
		den = sapply(split(O-P,f),function(x){ sum( x^2 ) } )
		N  = pmin(num/den, Nmax)
		return( N )
	}

	## Mean age residuals (Chris Francis) (deprecated)
	MRfun = function(y,a,O,P)  {
		Oay = a * O; Pay = a * P
		mOy = sapply(split(Oay,y),sum,na.rm=TRUE)
		mPy = sapply(split(Pay,y),sum,na.rm=TRUE)
		ry  = mOy - mPy
		return(ry) 
	}

	## Correction factor based on mean age residuals (deprecated)
	CFfun = function(y,N,a,O,P) {
		Oay = a * O; OAy = a^2 * O
		mOy = sapply(split(Oay,y),sum,na.rm=TRUE)
		MOy = sapply(split(OAy,y),sum,na.rm=TRUE)
		Vy  = MOy - mOy^2  # variance of the age frequency in year y
		ry  = MRfun(y,a,O,P)
		CF  = 1 / var(ry*(N/Vy)^.5)
		return(CF) 
	}

	## Mean age function (Chris Francis, 2011, weighting assumption T3.4, p.1137)
	## MAfun now in `utilFuns.r` (because it is needed here and in `runSweave`).

	## Method TA1.8 Weigting assumption T3.4 in Francis (2011, CJFAS, p.1137) Table A1
	## See plotMeanAge.r for debugging
	wfun = function (MAlist) {
		# y=year, a=age bin, O=observed proportions, P=Predicted (fitted) proportions, N=sample size, J=series
		unpackList(MAlist,scope="L")
		w    = rep(1,length(J)); names(w)=J
		jvec = substring(names(N),1,nchar(names(N))-5)
		wN   = N
		for (j in 1:length(J)) {
			jj = J[j]
			z = is.element(jvec,jj); zNoVar = is.element(Vexp,0); zNoVal = is.element(MAexp,0) & zNoVar
			# Only use values in series jj with non-zero variance and with fitted values
			zUse = z&!zNoVar&!zNoVal
			if (!any(zUse) || sum(zUse)<=1) next
			## Method TA1.8 Weigting assumption T3.4 in Francis (2011) Table A1
			w[j] = 1 / var((MAobs[zUse]-MAexp[zUse])/((Vexp[zUse]/N[zUse])^0.5) )
			#w[j] = ifelse(length(J)==1, 6.321921, 0.25)  ## sabotage Run75 for YMR 2021 to use Harmonic Mean Ratio for fishery AF and downweight surveys
			wN[zUse] = N[zUse] * w[j]
#browser();return()
		}
		return(list(w=w,wN=wN))
	}
	##===== end subfuns =====

	##===== start main =====
	#do.cvpro = if (is.numeric(cvpro[1])) TRUE else do.cvpro=cvpro[1]
	#if (do.cvpro && is.logical(cvpro[1]) && cvpro[1]==TRUE)
	#	cvpro = rep(0.2, length(cvpro))

	## Abundance data -- Surveys
	## Reweight methods: 0=no reweight, 1=add/subtract pocess error, 2=SDNR
	survey    =  res$Survey[!is.na(res$Survey[,"Obs"]),]
	Sseries   = sort(unique(survey[,"Series"]))
	SDNR      = rep(0,length(Sseries)); names(SDNR) = Sseries
	survey$NR = NRfun(survey$Obs,survey$Fit,survey$CV)
	survey$CVnew = rep(0,nrow(survey))

	for (s in Sseries) {
		## single event by Sseries s
		ss = as.character(s)
		zs = is.element(survey$Series,s)
		sser = survey[zs,]
		SDNR[ss] = sd(sser$NR)

		## Check that this routine is repeated for the CPUE series below

		if (A.rwt==1) {  ## add specified process error
			.flash.cat(paste0("   CV reweight ", nrwt, " -- survey ", s, " with CVpro=",cvpro[s]),"\n")
			## Need to subtract if cvpro < 0
			if (cvpro[s] >= 0)
				survey$CVnew[zs] = sqrt(survey$CV[zs]^2 + cvpro[s]^2)
			else
				survey$CVnew[zs] = sqrt(survey$CV[zs]^2 - cvpro[s]^2)

		} else if (A.rwt==2) { ## use SDNR method
			.flash.cat(paste0("   CV reweight ", nrwt, " -- survey ", s, " with SDNR=",SDNR[ss]), "\n")
			survey$CVnew[zs] = sser$CV * SDNR[ss]

		} else { ## no reweight or no defined method
			#.flash.cat(paste0("   CV reweight ", nrwt, " not performed -- survey ", s), "\n")
			survey$CVnew[zs] = survey$CV[zs]
		}
	}

	## Abundance data -- CPUE indices
	## Reweight methods: 0=no reweight, 1=add/subtract pocess error, 2=SDNR
	if (all(view(obj,pat="CPUE likelihood",see=FALSE)[[1]]==0)) {
		cpue = NULL
	} else {
		cpue =  res$CPUE[!is.na(res$CPUE[,"Obs"]),]
		Utmp = sort(unique(cpue[,"Series"])); Useries = gsub("Series","cpue",Utmp); names(Useries) = Utmp
		sdnr = rep(0,length(Useries)); names(sdnr) = Useries; SDNR = c(SDNR,sdnr)
		cpue$NR = NRfun(cpue$Obs,cpue$Fit,cpue$CV)
		cpue$CVnew = rep(0,nrow(cpue))
		for (u in names(Useries)) {
			s  = s + 1  ## to index cvpro for CPUE; s continued from surveys above
			uu = as.character(u)
			zu = is.element(cpue$Series,u)
			user = cpue[zu,]
			SDNR[Useries[uu]] = sd(user[,"NR"])

			if (A.rwt==1) {  ## add specified process error
				.flash.cat(paste0("   CV reweight ", nrwt, " -- CPUE ", u, " with CVpro=", cvpro[s]), "\n")
				## Need to subtract if cvpro < 0
				if (cvpro[s] >= 0)
					cpue$CVnew[zu] = sqrt(cpue$CV[zu]^2 + cvpro[s]^2)
				else
					cpue$CVnew[zu] = sqrt(cpue$CV[zu]^2 - cvpro[s]^2)

			} else if (A.rwt==2) { ## use SDNR method
				.flash.cat(paste0("   CV reweight ", nrwt, " -- CPUE ", u, " with SDNR=", SDNR[Useries[uu]]), "\n")
				cpue$CVnew[zu] = user$CV * SDNR[Useries[uu]]

			} else { ## no reweight or no defined method
				#.flash.cat(paste0("   CV reweight ", nrwt, " not performed -- CPUE ", u), "\n")
				cpue$CVnew[zu] = cpue$CV[zu]
			}
		}
	}
	sdnr = rep(0,2); names(sdnr) = c("spa","cpa"); SDNR = c(SDNR,sdnr,dev=sum(abs(1-SDNR)))
	wj   = NULL

	## Composition data -- Commercial proportions-at-age
	## Reweight methods: 0=no reweight, 1=Francis (2011) mean age, 2=SDNR
	CAc  = res$CAc
	cpa  = CAc[!is.na(CAc$SS),]
	## SD and NR not used by Francis' mean weighting but calculated for SDNR reporting anyway
	## No formulae appropriate for composition-data likelihoods due to correlations (Francis 2011, Appendix B, CJFAS)
	cpa$SD = SDfun(cpa$Obs, cpa$SS, A=length(unique(cpa$Sex))*length(unique(cpa$Age)) )
	cpa$NR = NRfun(cpa$Obs, cpa$Fit, cpa$SD, maxR=3, logN=FALSE)

	if (C.rwt==1) {  ## Francis mean age
		.flash.cat(paste0("   AF SS reweight ", nrwt, " using mean age -- commercial"), "\n") ## age frequency sample size
		MAc   = MAfun(cpa) ## commercial mean ages
		Wc    = wfun(MAc)
		wNcpa = Wc$wN
		wtemp = Wc$w
		if (obj@controls$NyrCAc==0)  wtemp[names(wtemp)] = 1
		names(wtemp) = paste0("cpa-",names(wtemp))
		wj = c(wj,wtemp)
#browser();return()

	} else if (C.rwt==2) { ## use SDNR method
		.flash.cat(paste0("   AF SS reweight ", nrwt, " using SDNRs -- commercial"), "\n")
		.flash.cat("   AF reweight by SDNRs -- commercial\n")
		wNcpa = eNfun(cpa$Series,cpa$Year,cpa$Obs,cpa$Fit)

	} else { ## no reweight or no defined method
		#.flash.cat(paste0("   AF SS reweight ", nrwt, " not performed -- commercial"), "\n")
		cpa.tmp = cpa
		cpa.tmp$index = paste(cpa$Series,cpa$Year,sep="-")
		wNcpa = sapply(split(cpa.tmp$SS,cpa.tmp$index),unique)
	}

	SDNR["cpa"] = sd(cpa$NR,na.rm=TRUE)
	if (obj@controls$NyrCAc == 0) SDNR["cpa"] = 0

	## Composition data -- Survey proportions-at-age
	## Reweight methods: 0=no reweight, 1=Francis (2011) mean age, 2=SDNR
	CAs = res$CAs
	spa = CAs[!is.na(CAs$SS),]
	## SD and NR not used by Francis' mean weighting but calculated for SDNR reporting anyway
	## No formulae appropriate for composition-data likelihoods due to correlations (Francis 2011, Appendix B, CJFAS)
	spa$SD = SDfun(spa$Obs, spa$SS, A=length(unique(spa$Sex))*length(unique(spa$Age)) )
	spa$NR = NRfun(spa$Obs, spa$Fit, spa$SD, maxR=3, logN=FALSE)

	if (C.rwt==1) {  ## Francis mean age
		.flash.cat(paste0("   AF SS reweight ", nrwt, " using mean age -- survey"), "\n") ## age frequency sample size
		MAs   = MAfun(spa) ## survey mean ages
		Ws    = wfun(MAs)
		wNspa = Ws$wN
		wtemp = Ws$w
		if (obj@controls$NyrCAs==0) wtemp[names(wtemp)] = 1 
		names(wtemp)=paste("spa-",names(wtemp),sep="")
		wj = c(wj,wtemp)
	} else if (C.rwt==2) { ## use SDNR method
		.flash.cat(paste0("   AF SS reweight ", nrwt, " using SDNRs -- survey"), "\n")
		wNspa = eNfun(spa$Series,spa$Year,spa$Obs,spa$Fit)

	} else { ## no reweight or no defined method
		#.flash.cat(paste0("   AF SS reweight ", nrwt, " not performed -- survey"), "\n")
		spa.tmp = spa
		spa.tmp$index = paste(spa$Series,spa$Year,sep="-")
		wNspa = sapply(split(spa.tmp$SS,spa.tmp$index),unique)
	}

	SDNR["spa"] = sd(spa$NR,na.rm=TRUE)
	if (obj@controls$NyrCAs == 0) SDNR["spa"] = 0

	if (!is.null(dots$sfile)) {
		sfile=dots$sfile
		.flash.cat(paste("\n",dots$fileN," (",paste(names(SDNR),collapse=", "),")\n",sep=""))
		.flash.cat(paste(round(SDNR,5),collapse="\t"),"\n",sep="")  # cat to console
		cat("\n",dots$fileN,"\n",file=sfile,append=TRUE,sep="")
		cat("SDNR: ",paste(round(SDNR,5),collapse="\t"),"\n",file=sfile,append=TRUE,sep="")
		if (!is.null(wj)) {
			.flash.cat(paste("\n","wj (",paste(names(wj),collapse=", "),")\n",sep=""))
			.flash.cat(paste(round(wj,5),collapse="\t"),"\n",sep="")  # cat to console
			cat("wj:   ",paste(round(wj,5),collapse="\t"),"\n",file=sfile,append=TRUE,sep="")
		}
	} 
	#sMAR = MRfun(spa$Year,spa$Age,spa$Obs,spa$Fit) # srvey mean age residuals
	#w = c((1/SDNR)[as.character(c(Sseries,Useries))],(1/SDNR^2)[c("cpa","spa")]) # lognormal and multinomial (Francis)
	#f = c( cpa=CFfun(cpa$Year,cpa$SS,cpa$Age,cpa$Obs,cpa$Fit), spa=CFfun(spa$Year,spa$SS,spa$Age,spa$Obs,spa$Fit) )
#browser();return()
	obj@reweight = list(nrwt=nrwt+1,survey=survey,cpue=cpue,wNcpa=wNcpa,wNspa=wNspa,SDNR=SDNR,wj=wj)
	return(obj)
} )
##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~setMethod.reweight


##================================================
#out = readAD("input.txt")
#nvec = write(out)

##=== POP 3CD 2012 ===
#out=runADMB("pop-3CD-05.txt",strSpp="POP",runNo=5,doMPD=TRUE,N.reweight=1,mean.age=TRUE,cvpro=0.2,clean=TRUE)
#out=runADMB("pop-3CD-05.txt",strSpp="POP",runNo=5,doMPD=TRUE,N.reweight=0,ADargs=list("-nohess"),mean.age=TRUE,cvpro=0.2,clean=TRUE)

##=== YMR CST 2011 ===
#out=runADMB("input29-ymr.txt",runNo=29,doMPD=TRUE,N.reweight=1,ADargs=list("-nohess"),mean.age=TRUE,cvpro=0.2)
#out=runADMB("input36-ymr.txt",runNo=36,doMPD=TRUE,N.reweight=6,ADargs=list("-nohess"),mean.age=TRUE,cvpro=0.2)
#out=runADMB("input25-ymr.txt",runNo=25,rwtNo=1,doMCMC=TRUE,mcmc=1e6,mcsave=1e3,mean.age=TRUE,cvpro=0.2)
#out=runADMB("input24-ymr.txt",runNo=24,rwtNo=1,doMSY=TRUE,msyMaxIter=15000,msyTolConv=0.01,endStrat=0.301,stepStrat=0.001)

##=== POP QCS 2010 ===
#out=runADMB("s3age-estmh02.txt",doMPD=FALSE,doMCMC=TRUE,mcmc=1000,mcsave=100)
#out=runADMB("s3age-estmh.txt",doMPD=TRUE,N.reweight=2,ADargs=list("-nohess"))
#out=runADMB("s3age-estmh.002.txt",doMPD=FALSE,doMCMC=TRUE,mcmc=1000,mcsave=100)
#out=runADMB("s3age-estmh.txt",doMPD=TRUE,N.reweight=1,doMCMC=TRUE,mcmc=1000,mcsave=100,ADargs=list("-nohess"))

#for (i in 29:30)
#	out=runADMB(paste("input",pad0(i,2),"-ymr.txt",sep=""),runNo=i,rwtNo=1,doMSY=TRUE,msyMaxIter=15000,msyTolConv=0.01,endStrat=0.301,stepStrat=0.001)

#out=runADMB("input26-ymr.txt",runNo=26,rwtNo=1,doMSY=TRUE)
#out=runADMB("input27-ymr.txt",runNo=27,rwtNo=1,doMSY=TRUE)
#out=runADMB("input28-ymr.txt",runNo=28,rwtNo=1,doMSY=TRUE)

##================================================
#source("PBSscape.r"); source("runSweave.r"); source("runSweaveMCMC.r"); source("plotFuns.r"); source("menuFuns.r"); source("utilFuns.r"); 

##=== ROL 5CD 2013 ===
#out=runADMB("ROL-5CD-01.txt",strSpp="ROL",runNo=1,doMPD=TRUE,N.reweight=3,mean.age=TRUE,cvpro=0.2,clean=TRUE)
#out=runADMB("ROL-5CD-04.txt",strSpp="ROL",runNo=4,doMPD=TRUE,N.reweight=3,mean.age=TRUE,cvpro=0.2,clean=TRUE)
#out=runADMB("ROL-5CD-05.txt", strSpp="ROL", runNo=5, doMPD=TRUE,N.reweight=3, mean.age=TRUE, cvpro=0.2, clean=TRUE, locode=TRUE)

##=== ROL 5AB 2013 ===
#out=runADMB("ROL-5AB-07.txt",strSpp="ROL",runNo=7,doMPD=TRUE,N.reweight=3,mean.age=TRUE,cvpro=0.25,clean=TRUE)
#out=runADMB("ROL-5AB-08.txt",strSpp="ROL",runNo=8,doMPD=TRUE,N.reweight=3,mean.age=TRUE,cvpro=0.35,clean=TRUE)

##=== ROL 5ABCD 2013 ===
#out=runADMB("ROL-5ABCD-01.txt",strSpp="ROL",runNo=1,doMPD=TRUE,N.reweight=3,mean.age=TRUE,cvpro=c(0.35,0.2,0.1,0.2,0.35),clean=TRUE,locode=TRUE)

##=== SGR CST 2013 ===
#out=runADMB("SGR-CST-01.txt",strSpp="SGR",runNo=1,doMPD=TRUE,N.reweight=3,mean.age=TRUE,cvpro=0.35,clean=TRUE)

##=== YTR CST 2014 ===
#out=runADMB("YTR-CST2F-05.txt",strSpp="YTR",runNo=5,doMPD=T,N.reweight=2,mean.age=T,cvpro=c(0.5, 0.15, 0.5, 0.6, 0.6, 0.6),clean=T, locode=T)
#outADM = runADMB("YTR-CST1F-05.txt",strSpp="YTR",runNo=5,doMPD=T,N.reweight=2,mean.age=T,cvpro=c(0.5, 0.15, 0.5, 0.6, 0.6, 0.6),clean=T, locode=T) #awateaPath=".")

##=== RBR CST 2014 ===
#outADM=runADMB("RBR-CST2F-01.txt", strSpp="RBR", runNo=1, doMPD=T, N.reweight=1, mean.age=T, cvpro=c(0.2,0.3,0.2,0.2,0.2,0.2,0.2,0.2),clean=T, locode=T)

##=== POP 5ABC 2016 ===
#outADM=runADMB("POP-5ABC-02.txt", strSpp="POP", runNo=2, doMPD=T, N.reweight=1, mean.age=T, cvpro=c(0.2,0.2,0.2),clean=T, locode=T)

##=== WWR BC 2019 ===
#outADM=runADMB("WWR-BC-21.txt", strSpp="WWR", runNo=21, doMPD=T, N.reweight=2, A.reweight=c(1,0), C.reweight=c(0,1), mean.age=T, cvpro=c(rep(0,5), 0.1859), clean=T, locode=T)

