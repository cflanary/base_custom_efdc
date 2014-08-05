SUBROUTINE SEDIC
  USE GLOBAL
  IMPLICIT NONE
  INTEGER::CORE,I,J,L,LL,M,K,NS,VAR_BED,FDIR,NWV
  INTEGER::IWV,JWV,NSKIP,ERROR
  CHARACTER(LEN=80)::STR_LINE
  !PT- real values are written in DOUBLE PRECISION. 7/16/08
  REAL::STWVHTMP,STWVTTMP,STWVDTMP
  REAL,ALLOCATABLE,DIMENSION(:,:)::BDEN   !(INCORE,KB)
  REAL,ALLOCATABLE,DIMENSION(:,:)::TAUTEMP   !(KB)
  REAL,ALLOCATABLE,DIMENSION(:,:,:)::PNEW    !(INCORE,KB,NSCM)
  REAL,ALLOCATABLE,DIMENSION(:,:)::ATEMP 
  REAL,ALLOCATABLE,DIMENSION(:,:)::NTEMP

  ! Reads in Initial Erosion data.
  ! Reads in Erosion Data for Newly deposited 
  ! Sediments.
  ! Calculates bed parameters.
  ! Assuming ISEDDT in EFDCis 1
  ! REVISION DATE :  May 24, 2006
  ! Craig Jones and Scott James
  !**************************************************************************
  ! Set Maximum Number of Size Clases to be read in
  ! for newly deposited sediment erosion rates NSICM 
  ! Open Input Files
  ! Craig Jones
  !CALL SEDDATA !calls routine to convert SEDflume data into a form useable by this code
  OPEN(UNIT=10,FILE='erate.sdf')
  OPEN(UNIT=20,FILE='core_field.sdf')
  OPEN(UNIT=30,FILE='bed.sdf')
  ! Read in Sediment Transport Parameters
  ! VAR_BED  =  1 for variable sediment bed
  ! NCALC_BL =  1 for bedload  calculation
  ! NEQUIL   =  1 for finite sorption contaminant process in water column
  READ (30,'(A80)') STR_LINE
  READ (30,*) VAR_BED,NCALC_BL,NEQUIL,KB,ISEDTIME,IMORPH_SEDZLJ,ISWNWAVE,MAXDEPLIMIT
  IF(IMORPH_SEDZLJ==1.AND.(IMORPH/=0.OR.ISGWIT>=2))THEN
     PRINT*,'EFDC and SEDZLJ MORPHOLOGIES BOTH TURNED ON'
     STOP
  ENDIF
  READ (30,'(A80)') STR_LINE !SKIP THESE LINES
  READ (30,'(A80)') STR_LINE ! DATA READ BY SCANSEDZLJ; ITBM and NSICM.
  READ (30,'(A80)') STR_LINE
  READ (30,*)  ZBSKIN,TAUCONST,ISSLOPE
  READ (30,'(A80)') STR_LINE
  READ (30,*) (D50(K),K=1,NSCM)
  READ (30,'(A80)') STR_LINE
  READ (30,*) (TCRE(K),K=1,NSCM) 
  READ (30,'(A80)') STR_LINE
  READ (30,*) (TCRSUS(K),K=1,NSCM)
  ! Hydrophobic Contaminant Information
  IF(NSEDFLUME==2)THEN
     READ (30,'(A80)') STR_LINE
     READ (30,*) (KPART(K),K=1,NSCM)
     READ (30,'(A80)') STR_LINE
     READ (30,*) (DIFFCOFF(K),K=1,NSCM)
     READ (30,'(A80)') STR_LINE
     DO LL=1,KB
        READ(30,*) (PCONTEMP(K,LL),K=1,NSCM)
     ENDDO
  ENDIF
  !**************************************************************************
  !Reading in Erate.sdf starting with the layer's thickness.
  READ (10,'(A80)') STR_LINE
  READ (10,*) (TSED0S(LL),LL=1,KB)
  READ (10,'(A80)') STR_LINE
  READ (10,*) TACTM !read in active layer multiplier
! Read in Initial Erosion Data
  IF(VAR_BED>=1)THEN    
! Variable Bed *************************************************
     READ(20,*)INCORE !read the number of cores    
     ALLOCATE(TAUTEMP(INCORE,KBM))
     ALLOCATE(PNEW(INCORE,KBM,NSCM+1))
     ALLOCATE(BDEN(INCORE,KBM))
     ALLOCATE(NTEMP(INCORE,KBM))
     ALLOCATE(ATEMP(INCORE,KBM))
     TAUTEMP=0.0
     PNEW=0.0
     BDEN=0.0   
     ! Read variable bed in I,J,core format for L=2,LA locations
     DO L=2,LA 
        READ(20,*,IOSTAT=ERROR) I,J,NCORENO(I,J)
        IF(ERROR==1)THEN
		  WRITE(*,'("READ ERROR IN CORE INPUT FILE")')  
		  WRITE(8,'("READ ERROR IN CORE INPUT FILE")')  
		  STOP 
        ENDIF
     ENDDO
 !*************************************************************   
     DO CORE=1,INCORE !for each core of data      
       READ (10,'(A80)') STR_LINE
       READ(10,*)(TAUTEMP(CORE,LL),LL=1,KB) !read the critical shear stresses of the core
       READ (10,'(A80)') STR_LINE			
       READ(10,*)(BDEN(CORE,LL),LL=1,KB) !read in the bulk density of the core 
       READ (10,'(A80)') STR_LINE			
       READ(10,*) WATERDENS, SEDDENS !read in the water density and sediment solid's density
       READ (10,'(A80)') STR_LINE	
       DO LL=1,KB
         READ(10,*)(PNEW(CORE,LL,K),K=1,NSCM)
       ENDDO
              
       READ (10,'(A80)') STR_LINE
       DO LL=1,KB
         READ(10,*) ATEMP(CORE,LL),NTEMP(CORE,LL)
       ENDDO
!       DO K=1,ITBM
!         READ(10,*)TAULOC(K) !shear stress used to erode a portion of the core
!         READ(10,*)(ERATETEMP(CORE,LL,K),LL=1,KB) !erosion rate for each layer subject to shear stress TAULOC
!       ENDDO
     ENDDO     
     DO L=2,LA
       I=IL(L) !I location as a function of L
       J=JL(L) !J location as a function of L      
       TAUCOR(1:KB,L)=TAUTEMP(NCORENO(I,J),1:KB) !Critical shear stresses from cores
       DO LL=1,KB
!         FORALL(M=1:ITBM)ERATE(LL,L,M)=ERATETEMP(NCORENO(I,J),LL,M) !set erosion rate to measured value

         FORALL(K=1:NSCM)PER(K,LL,L)=PNEW(NCORENO(I,J),LL,K)/100.0 !set mass fraction to measured value
         A_P(LL,L)=ATEMP(NCORENO(I,J),LL)
         N_P(LL,L)=NTEMP(NCORENO(I,J),LL)
!         BULKDENS(LL,L)=(SEDDENS/(SEDDENS-WATERDENS))*(BDEN(NCORENO(I,J),LL)-1.0)  !Converts wet to dry bulk density
         BULKDENS(LL,L)=BDEN(NCORENO(I,J),LL) ! For input in dry density
       ENDDO
     ENDDO  
! Constant Erosion in Horizontal ********************************
   ELSE
     ALLOCATE(TAUTEMP(1,KBM))
     ALLOCATE(PNEW(1,KBM,NSCM))
     ALLOCATE(BDEN(1,KBM))   
     ALLOCATE(NTEMP(1,KBM))
     ALLOCATE(ATEMP(1,KBM))

     CORE=1    
     DO L=2,LA
        I=IL(L)
        J=JL(L)
        NCORENO(I,J)=1
     ENDDO

     READ (10,'(A80)') STR_LINE
     READ(10,*)(TAUTEMP(CORE,LL),LL=1,KB) !read the critical shear stresses of the core
     READ (10,'(A80)') STR_LINE			
     READ(10,*)(BDEN(CORE,LL),LL=1,KB) !read in the bulk density of the core 
     READ (10,'(A80)') STR_LINE			
     READ(10,*) WATERDENS, SEDDENS !read in the water density and sediment solid's density 
     READ (10,'(A80)') STR_LINE	
     DO LL=1,KB
        READ(10,*)(PNEW(CORE,LL,K),K=1,NSCM)
     ENDDO
     
     READ (10,'(A80)') STR_LINE
     DO LL=1,KB
       READ(10,*) ATEMP(CORE,LL),NTEMP(CORE,LL)
     ENDDO
!     DO K=1,ITBM
!        READ(10,*)TAULOC(K) !shear stress used to erode a portion of the core
!        READ(10,*)(ERATETEMP(CORE,LL,K),LL=1,KB) !erosion rate for each layer subject to shear stress TAULOC
!     ENDDO

     
     DO L=2,LA
        DO LL=1,KB
           TAUCOR(LL,L)=TAUTEMP(1,LL)
!           FORALL(M=1:ITBM)ERATE(LL,L,M)=ERATETEMP(1,LL,M)
           A_P(LL,L)=ATEMP(1,LL)
           N_P(LL,L)=NTEMP(1,LL)
           FORALL(K=1:NSCM)PER(K,LL,L)=PNEW(1,LL,K)/100.0
!        BULKDENS(LL,L)=(SEDDENS/(SEDDENS-WATERDENS))*(BDEN(NCORENO(I,J),LL)-1.0)  !Converts wet to dry bulk density
         BULKDENS(LL,L)=BDEN(CORE,LL) ! For input in dry density
        ENDDO
     ENDDO
     

  ENDIF
  FORALL(LL=1:KB)BEDDINIT(2:LA,LL)=BULKDENS(KB+1-LL,2:LA)
  FORALL(LL=1:KB)BEDBINIT(2:LA,LL)=BEDDINIT(2:LA,LL)*1.65D0/2.65D0+1000.0D0
  FORALL(LL=1:KB)PORBED(2:LA,LL)=0.001D0*(BEDBINIT(2:LA,LL)-BEDDINIT(2:LA,LL))
  FORALL(LL=KB-1:KB)BEDLINIT(2:LA,LL)=0.0
  FORALL(LL=1:KB-2)BEDLINIT(2:LA,LL)=0.01*MAX(1E-12,TSED0S(KB+1-LL))
  FORALL(LL=1:KB)HBED(2:LA,LL)=BEDLINIT(2:LA,LL)
  FORALL(L=2:LA,LL=1:KB-2,NS=1:NSCM)SEDB(L,LL,NS)=BULKDENS(KB+1-LL,L)*PER(NS,KB+1-LL,L)/HBED(L,LL)
  FORALL(L=2:LA,LL=1:KB-2,NS=1:NSCM)SEDB1(L,LL,NS)=SEDB(L,LL,NS)
  FORALL(L=2:LA)KBT(L)=KB
  !**************************************************************************
  !
  ! Set Initial Layer and Thickness Values
  !
 !  FORALL(L=2:LA)
   DO L=2,LA
     WHERE(TSED0S(1:KB)>0.0)
       LAYER(1:KB,L)=1
     ELSEWHERE
       LAYER(1:KB,L)=0
     ENDWHERE
     FORALL(LL=1:KB)
        TSED(LL,L)=TSED0S(LL)*BULKDENS(LL,L)! PT TSED in units of (g/cm^2).
        TSED0(LL,L)=TSED0S(LL)*BULKDENS(LL,L)! PT TSED0 in units of (g/cm^2).
     ENDFORALL
   ENDDO
 ! ENDFORALL
  FORALL(L=2:LA)TSET0T(L)=SUM(TSED0(1:KB,L)/BULKDENS(1:KB,L))
  FORALL(L=2:LA)HBEDA(L)=SUM(BEDLINIT(L,1:KB))
  FORALL(L=2:LA)ZELBEDA(L)=BELV(L)-HBEDA(L)
  ! Read in Newly deposited sediment
  ! Erosion Rates (ERATEND) and Critical 
  ! Shear Stress for Erosion (TAUCRITE).
  READ (30,'(A80)') STR_LINE
  READ (30,*)  (SCND(NSC),NSC=1,NSICM)
  READ (30,'(A80)') STR_LINE
  READ (30,*)  (TAUCRITE(NSC),NSC=1,NSICM)
  READ (30,'(A80)') STR_LINE
  DO NSC=1,NSICM
     READ(30,*) A_ND(NSC),N_ND(NSC)
  ENDDO
  ! Settling speed (DWS) calculated from D50 (micron) 
  ! input diameter using Cheng's model (1998).  Settling speed in cm/s
  DO K=1,NSCM
     IF(BSC>0.0)THEN !if variable density, take it into account
       DISTAR(K)=D50(K)/10000.0*(((SEDDENS/((B(L,K)+1.0)*1.0000))-1.0)*980.0/0.01**2)**(1.0/3.0) !SCJ changed 1000.0 to 1.0000
     ELSE
       DISTAR(K)=D50(K)/10000.0*(((SEDDENS/WATERDENS)-1.0)*.9800/0.01**2)**(1.0/3.0) !SCJ changed 980.0 to .9800
     ENDIF
     DWS(K)=0.01/(D50(K)*0.0001)*(SQRT(25.0+1.2*DISTAR(K)**2)-5.0)**1.5
  ENDDO
  !**************************************************************************
  ! Contaminant Transport Model
  IF(NSEDFLUME==2) THEN
     ! Initialize Contaminant Transport Variables
     ! CONSCM = Concentration of contaminant on Sediment (ug/cm^3)
     ! CONDISS = Dissolved phase of contaminant (ug/cm^3)
     FORALL(L=2:LA)
        FORALL(K=1:KC,N=1:NTOX)
           TOX(L,K,N)=0.0
           TOX1(L,K,N)=0.0
        ENDFORALL
        FORALL(LL=1:KB,NS=1:NSCM)PCONT(NS,LL,L)=PCONTEMP(NS,LL)
     ENDFORALL
  ENDIF
  ! END Contaminant Transport
  !**************************************************************************
  ! Read in Wave Fetch or STWAVE Data if Used
  IF (ISWNWAVE.EQ.1) THEN
     
     OPEN(UNIT=50,FILE='fetch.inp')
     DO L=2,LA
        READ (50,*) I,J,(FWDIR(LIJ(I,J),FDIR),FDIR=1,8)
     ENDDO
     CLOSE(50)
     
  ELSEIF (ISWNWAVE.EQ.2)THEN
     
     OPEN(UNIT=51,FILE='stwave.inp')
     
     DO NSKIP=1,5  
        READ (51,'(A80)') STR_LINE   
     ENDDO
     
     READ(51,*) STWVNUM,STWVTIM
     
     STWVTIM=STWVTIM*DT/3600.0
     
     DO NWV=1,STWVNUM  
        READ (51,'(A80)') STR_LINE
        !READ(51,*)IWV,JWV,STWVHT(2,NWV),STWVTP(2,NWV),STWVDR(2,NWV)
        
        DO L=2,LA
           READ(51,*)IWV,JWV,STWVHTMP,STWVTTMP,STWVDTMP
           STWVHT(LIJ(IWV,JWV),NWV)=STWVHTMP
           STWVTP(LIJ(IWV,JWV),NWV)=STWVTTMP
           STWVDR(LIJ(IWV,JWV),NWV)=STWVDTMP
           !STWVHT(L,NWV)=STWVHT(2,NWV)
           !STWVTP(L,NWV)=STWVTP(2,NWV)
           !STWVDR(L,NWV)=STWVDR(2,NWV)	   
        ENDDO
        ! Incremental counter for which wave data set we are on
        STINC=0
        NWVCOUNT=STWVTIM-1
     ENDDO
     
     CLOSE(51)
  ENDIF
  
  !**************************************************************************
  
  FORALL(NS=1:NSCM)SSGI(NS)=1.0/(1.0E6*SSG(NS))  !initialize SSGI
  
  WRITE(6,*)'**************************************'
  WRITE(6,*)'Input Sizes (micron)'
  WRITE(6,*)(SCND(K),K=1,NSICM) 
  WRITE(6,*)'**************************************'
  WRITE(6,*)'Input Critical Shear Ero dynes/cm^2'
  WRITE(6,*)(TAUCRITE(K),K=1,NSICM) 
  WRITE(6,*)'**************************************'
  WRITE(6,*)'Sediment Sizes (micron)'
  WRITE(6,*)(D50(K),K=1,NSCM) 
  WRITE(6,*)'**************************************'
  WRITE(6,*)'DISTAR for each size class'
  WRITE(6,*)(DISTAR(K),K=1,NSCM) 
  WRITE(6,*)'**************************************'
  WRITE(6,*)'Critical Shear Sus dynes/cm^2 '
  WRITE(6,*)(TCRSUS(K),K=1,NSCM) 
  WRITE(6,*)'**************************************'
  WRITE(6,*)'Critical Shear Ero dynes/cm^2 '
  WRITE(6,*)(TCRE(K),K=1,NSCM) 
  WRITE(6,*)'**************************************'
  WRITE(6,*)'Settling Speeds in cm/s'
  WRITE(6,*)(DWS(K),K=1,NSCM) 
  WRITE(6,*)'**************************************'
  WRITE(6,*)' Surface Sediment Density  (g/cm^3) '
  WRITE(6,*)BULKDENS(3,3)
  WRITE(6,*)'**************************************'
  
  DEALLOCATE(TAUTEMP,BDEN,PNEW,NTEMP,ATEMP)
  CLOSE(10)
  CLOSE(20)
  CLOSE(30)
  CLOSE(40)
  RETURN
END SUBROUTINE SEDIC

