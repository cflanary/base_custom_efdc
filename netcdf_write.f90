SUBROUTINE netcdf_write

! Writes EFDC output to NetCDF file

! 7/3/2014 Chris Flanary

USE GLOBAL
USE netcdf
IMPLICIT NONE

LOGICAL,SAVE::FIRST_NETCDF=.FALSE.
CHARACTER (len = *), PARAMETER :: FILE_NAME = "efdc_his.nc"
INTEGER, SAVE :: nc_step, ncid
INTEGER :: I, J, K, L, S, T, status
INTEGER, SAVE :: I_dimid,J_dimid,k_dimid,kb_dimid,time_dimid
INTEGER, SAVE :: ts_varid,time_varid,X_varid,Y_varid,belev_varid,mask_varid
INTEGER, SAVE :: surfel_varid,u_varid,v_varid,sal_varid,dye_varid
INTEGER, SAVE :: tss_varid,tau_varid,taumax_varid,d50_varid,thick_varid
INTEGER, SAVE :: vmax_varid, erate_varid, taucrit_varid, tsed_varid, psed_varid

INTEGER :: start(1), start_3d(3), start_4d(4), start_5d(5)
REAL, DIMENSION(1) :: deltat
REAL*8::time_efdc
REAL, DIMENSION(LCM) :: zeta,wet_dry_mask
REAL, DIMENSION(LCM) :: utmps,vtmps
REAL :: utmpa,vtmpa
REAL, DIMENSION(LCM) :: vel_max,vel_magc

! Allocate 2D time varying parameters
REAL, ALLOCATABLE, DIMENSION(:,:) :: lat,lon,hz
REAL, ALLOCATABLE, DIMENSION(:,:) :: mask,wl,u_2d,v_2d,salt,dye_2d
REAL, ALLOCATABLE, DIMENSION(:,:) :: shear,maxshear,grain_size,sed_thick,mag
REAL, ALLOCATABLE, DIMENSION(:,:) :: e_rate, tau_crit
REAL, ALLOCATABLE, DIMENSION(:,:,:) :: tss, sed_mass
REAL, ALLOCATABLE, DIMENSION(:,:,:,:) :: perc_sed
ALLOCATE(lat(JC-2,IC-2))
ALLOCATE(lon(JC-2,IC-2))
ALLOCATE(hz(JC-2,IC-2))
ALLOCATE(mask(JC-2,IC-2))
ALLOCATE(wl(JC-2,IC-2))
ALLOCATE(u_2d(JC-2,IC-2))
ALLOCATE(v_2d(JC-2,IC-2))
ALLOCATE(mag(JC-2,IC-2))
ALLOCATE(shear(JC-2,IC-2))
ALLOCATE(maxshear(JC-2,IC-2))
IF(ISTRAN(1).EQ.1) ALLOCATE(salt(JC-2,IC-2))
IF(ISTRAN(3).EQ.1) ALLOCATE(dye_2d(JC-2,IC-2))
IF(ISTRAN(6).EQ.1) THEN
    ALLOCATE(grain_size(JC-2,IC-2))
    ALLOCATE(sed_thick(JC-2,IC-2))
    ALLOCATE(tss(JC-2,IC-2,NSCM))
    ALLOCATE(e_rate(JC-2,IC-2))
    ALLOCATE(tau_crit(JC-2,IC-2))
!    ALLOCATE(vz_dif(JC-2,IC-2))
    ALLOCATE(sed_mass(JC-2,IC-2,KB))
    ALLOCATE(perc_sed(JC-2,IC-2,NSCM,KB))
ENDIF

! EFDC time parameter
time_efdc=DT*FLOAT(N)+TCON*TBEGIN
time_efdc=time_efdc/86400.

! Timing parameters
deltat=tidalp/float(ntsptc)
nc_step=nc_step+1

! Current write step
start=(/nc_step/)
start_3d=(/1,1,nc_step/)
start_4d=(/1,1,1,nc_step/)
start_5d=(/1,1,1,1,nc_step/)

! Create NetCDF file and define attributes
IF(.NOT.FIRST_NETCDF)THEN

   ! Create 2D lat, lon, and belev array for all cells
   DO I=3,IC-2
      DO J=3,JC-2
         IF(LIJ(I,J)>0) THEN
            lat(J,I)=DLAT(LIJ(I,J))
            lon(J,I)=DLON(LIJ(I,J))
            hz(J,I)=BELV(LIJ(I,J))
         ELSE
            lat(J,I)=-7999.
            lon(J,I)=-7999.
            hz(J,I)=-7999.
         ENDIF
      ENDDO
   ENDDO

    ! Create NetCDF file and overwrite if exists
    status=nf90_create(FILE_NAME, NF90_CLOBBER, ncid)
    if(status /= nf90_NoErr) call handle_err(status)

    !*************************************************************************************
    ! Variable definitions

    ! Define global attributes
    status=nf90_put_att(ncid, NF90_GLOBAL, 'title', 'EFDC Output')
    status=nf90_put_att(ncid, NF90_GLOBAL, 'file', FILE_NAME)
    status=nf90_put_att(ncid, NF90_GLOBAL, 'format', 'netCDF-3 64bit offset file')
    status=nf90_put_att(ncid, NF90_GLOBAL, 'os', 'Linux')
    status=nf90_put_att(ncid, NF90_GLOBAL, 'arch', 'x86_64')

    ! Define dimensions
    status=nf90_def_dim(ncid,'I',IC-2,I_dimid)
    status=nf90_def_dim(ncid,'J',JC-2,J_dimid)
    IF (ISTRAN(6).EQ.1) THEN
        status=nf90_def_dim(ncid,'NSCM',NSCM,k_dimid)
        status=nf90_def_dim(ncid,'KB',KB,kb_dimid)
    ENDIF
    status=nf90_def_dim(ncid,'efdc_time',nf90_unlimited,time_dimid)
    
    ! Define deltat
    status=nf90_def_var(ncid,'timestep',nf90_real,ts_varid)
    status=nf90_put_att(ncid, ts_varid, 'long_name', 'Numerical Timestep')
    status=nf90_put_att(ncid, ts_varid, 'units', 'seconds')

    ! Define model time
    status=nf90_def_var(ncid,'efdc_time',nf90_double,time_dimid,time_varid)
    status=nf90_put_att(ncid, time_varid, 'long_name', 'Time')
    status=nf90_put_att(ncid, time_varid, 'units', 'days')
    status=nf90_put_att(ncid, time_varid, 'ref_time', '20090516')
    status=nf90_put_att(ncid, time_varid, 'calendar', 'gregorian')

    ! Define coordinates variables
    status=nf90_def_var(ncid,'X',nf90_float,(/J_dimid,I_dimid/),X_varid)
    status=nf90_put_att(ncid, X_varid, 'long_name', 'X coordinate')
    status=nf90_put_att(ncid, X_varid, 'units', 'm')
    status=nf90_put_att(ncid, X_varid, 'coord_sys', 'UTM')
    status=nf90_put_att(ncid, X_varid, 'fill_value', -7999)

    status=nf90_def_var(ncid,'Y',nf90_float,(/J_dimid,I_dimid/),Y_varid)
    status=nf90_put_att(ncid, Y_varid, 'long_name', 'Y coordinate')
    status=nf90_put_att(ncid, Y_varid, 'units', 'm')
    status=nf90_put_att(ncid, Y_varid, 'coord_sys', 'UTM')
    status=nf90_put_att(ncid, Y_varid, 'fill_value', -7999)
    
    ! Define bottom elevation
    status=nf90_def_var(ncid,'belev',nf90_real,(/J_dimid,I_dimid/),belev_varid)
    status=nf90_put_att(ncid, belev_varid, 'long_name', 'Bottom Elevation')
    status=nf90_put_att(ncid, belev_varid, 'caxis_label', 'Bottom Elevation (m)')
    status=nf90_put_att(ncid, belev_varid, 'units', 'm')
    
    ! Define wet dry mask
    status=nf90_def_var(ncid,'wet_dry_mask',nf90_real,(/J_dimid,I_dimid, time_dimid/),mask_varid)
    status=nf90_put_att(ncid, mask_varid, 'long_name', 'Wet Dry Mask')
    status=nf90_put_att(ncid, mask_varid, 'caxis_label', 'Wet Dry Mask')
    status=nf90_put_att(ncid, mask_varid, 'dry_flag', '-99')
    status=nf90_put_att(ncid, mask_varid, 'wet_flag', '1')

    ! Define water surface elevation
    status=nf90_def_var(ncid,'zeta',nf90_real,(/J_dimid,I_dimid, time_dimid/),surfel_varid)
    status=nf90_put_att(ncid, surfel_varid, 'long_name', 'Surface Elevation')
    status=nf90_put_att(ncid, surfel_varid, 'caxis_label', 'Surface Elevation (m)')
    status=nf90_put_att(ncid, surfel_varid, 'units', 'm')

    ! Define u component velocity
    status=nf90_def_var(ncid,'u',nf90_float,(/J_dimid,I_dimid, time_dimid/),u_varid)
    status=nf90_put_att(ncid, u_varid, 'long_name', 'U Component Velocity')
    status=nf90_put_att(ncid, u_varid, 'units', 'm/s')

    ! Define v component velocity
    status=nf90_def_var(ncid,'v',nf90_float,(/J_dimid,I_dimid, time_dimid/),v_varid)
    status=nf90_put_att(ncid, v_varid, 'long_name', 'V Component Velocity')
    status=nf90_put_att(ncid, v_varid, 'units', 'm/s')
    
    ! Define max. velocity
    status=nf90_def_var(ncid,'vel_max',nf90_float,(/J_dimid,I_dimid/),vmax_varid)
    status=nf90_put_att(ncid, vmax_varid, 'long_name', 'Max. Velocity')
    status=nf90_put_att(ncid, vmax_varid, 'caxis_label', 'Max. Velocity (m/s)')
    status=nf90_put_att(ncid, vmax_varid, 'units', 'm/s')
    
    ! Define shear stress
    status=nf90_def_var(ncid,'tau',nf90_float,(/J_dimid,I_dimid, time_dimid/),tau_varid)
    status=nf90_put_att(ncid, tau_varid, 'long_name', 'Instant Shear Stress')
    status=nf90_put_att(ncid, tau_varid, 'caxis_label', 'Shear Stress (dynes/cm^2)')
    status=nf90_put_att(ncid, tau_varid, 'units', 'dynes/cm^2')
    
    ! Define maximum shear stress
    status=nf90_def_var(ncid,'taumax',nf90_float,(/J_dimid,I_dimid/),taumax_varid)
    status=nf90_put_att(ncid, taumax_varid, 'long_name', 'Maximum Shear Stress')
    status=nf90_put_att(ncid, taumax_varid, 'caxis_label', 'Max. Shear Stress (dynes/cm^2)')
    status=nf90_put_att(ncid, taumax_varid, 'units', 'dynes/cm^2')

    IF (ISTRAN(1).EQ.1) THEN
        ! Define salinity
        status=nf90_def_var(ncid,'salt',nf90_float,(/J_dimid,I_dimid, time_dimid/),sal_varid)
        status=nf90_put_att(ncid, sal_varid, 'long_name', 'Salinity')
        status=nf90_put_att(ncid, sal_varid, 'caxis_label', 'Salinity (psu)')
        status=nf90_put_att(ncid, sal_varid, 'units', 'psu')
    ENDIF
    
    IF(ISTRAN(3).EQ.1) THEN
        ! Define dye concentration
        status=nf90_def_var(ncid,'dye',nf90_float,(/J_dimid,I_dimid, time_dimid/),dye_varid)
        status=nf90_put_att(ncid, dye_varid, 'long_name', 'Dye Concentration')
        status=nf90_put_att(ncid, dye_varid, 'caxis_label', 'Dye Concentration (mg/L)')
        status=nf90_put_att(ncid, dye_varid, 'units', 'mg/L')
    ENDIF

    IF (ISTRAN(6).EQ.1) THEN
        ! Define water column TSS
        status=nf90_def_var(ncid,'tss',nf90_float,(/J_dimid,I_dimid,k_dimid,time_dimid/),tss_varid)
        status=nf90_put_att(ncid, tss_varid, 'long_name', 'Total Suspended Solids')
        status=nf90_put_att(ncid, tss_varid, 'caxis_label', 'TSS (mg/L)')
        status=nf90_put_att(ncid, tss_varid, 'units', 'mg/L')
        
        
        ! Define D50 grain size
        status=nf90_def_var(ncid,'D50',nf90_float,(/J_dimid,I_dimid, time_dimid/),d50_varid)
        status=nf90_put_att(ncid, d50_varid, 'long_name', 'Median Grain Size')
        status=nf90_put_att(ncid, d50_varid, 'caxis_label', 'Median Grain Size (um)')
        status=nf90_put_att(ncid, d50_varid, 'units', 'um')

        ! Define sediment thickness
        status=nf90_def_var(ncid,'thickness',nf90_float,(/J_dimid,I_dimid, time_dimid/),thick_varid)
        status=nf90_put_att(ncid, thick_varid, 'long_name', 'Bed Thickness')
        status=nf90_put_att(ncid, thick_varid, 'caxis_label', 'Bed Thickness (cm)')
        status=nf90_put_att(ncid, thick_varid, 'units', 'cm')
        
        ! Define total erosion rate
        status=nf90_def_var(ncid,'erate',nf90_float,(/J_dimid,I_dimid, time_dimid/),erate_varid)
        status=nf90_put_att(ncid, erate_varid, 'long_name', 'Total Erosion Rate')
        status=nf90_put_att(ncid, erate_varid, 'caxis_label', 'Total Erosion Rate (g/cm^2/ts)')
        status=nf90_put_att(ncid, erate_varid, 'units', 'g/cm^2/ts')
        
        ! Define bed critical shear stress
        status=nf90_def_var(ncid,'taucrit',nf90_float,(/J_dimid,I_dimid, time_dimid/),taucrit_varid)
        status=nf90_put_att(ncid, taucrit_varid, 'long_name', 'Bed Critical Shear Stress')
        status=nf90_put_att(ncid, taucrit_varid, 'caxis_label', 'Bed Critical Shear Stress (dynes/cm^2)')
        status=nf90_put_att(ncid, taucrit_varid, 'units', 'dynes/cm^2')
        
        ! Define water column vertical diffusivity
        !status=nf90_def_var(ncid,'vzdif',nf90_float,(/J_dimid,I_dimid, time_dimid/),vzdif_varid)
        !status=nf90_put_att(ncid, vzdif_varid, 'caxis_label', 'Vertical Diffusivity (m^2/s)')
        !status=nf90_put_att(ncid, vzdif_varid, 'units', 'm^2/s')
        
        ! Define cell sediment mass
        status=nf90_def_var(ncid,'tsed',nf90_float,(/J_dimid,I_dimid,kb_dimid,time_dimid/),tsed_varid)
        status=nf90_put_att(ncid, tsed_varid, 'long_name', 'Sediment Mass per Cell')
        status=nf90_put_att(ncid, tsed_varid, 'caxis_label', 'Cell Sed. Mass (g/cm^2)')
        status=nf90_put_att(ncid, tsed_varid, 'units', 'g/cm^2')
        
        ! Define percent of sediment size class in each layer
        status=nf90_def_var(ncid,'per',nf90_float,(/J_dimid,I_dimid,k_dimid,kb_dimid,time_dimid/),psed_varid)
        status=nf90_put_att(ncid, psed_varid, 'long_name', 'Percent of Sediment Size Class per Cell per Layer')
        status=nf90_put_att(ncid, psed_varid, 'caxis_label', 'Percent of Size Class (%)')
        status=nf90_put_att(ncid, psed_varid, 'units', '%')
    ENDIF
    
    ! End define mode
    status=nf90_enddef(ncid)

    !*************************************************************************************
    ! Put first step variables into file

    ! Put EFDC time step into file once
    status=nf90_put_var(ncid, ts_varid, deltat)
    if(status /= nf90_NoErr) call handle_err(status)

    ! Put coordinates into file
    status=nf90_put_var(ncid,X_varid,lon)
    if(status /= nf90_NoErr) call handle_err(status)
    status=nf90_put_var(ncid,Y_varid,lat)
    if(status /= nf90_NoErr) call handle_err(status)
    
    ! Put bottom elevation
    status=nf90_put_var(ncid,belev_varid,hz)
    if(status /= nf90_NoErr) call handle_err(status)

    FIRST_NETCDF=.TRUE.
    
    ! Initialize variables
    vel_magc=0.0
    vel_max=0.0
    TAUMAX=0.0

ENDIF

DO L=2,LA
    ! Calculate surface elevations for all active cells
    zeta(L)=(HP(L)+BELV(L))

    ! Create wet dry mask
    IF (HP(L)<=HDRY) THEN
        wet_dry_mask(L)=-99.
    ELSE
        wet_dry_mask(L)=1.
    ENDIF
    
    ! Calculate sediment thickness
    TSET0T(L)=SUM(TSED0(1:KB,L)/BULKDENS(1:KB,L))
    TSEDT(L)=SUM(TSED(1:KB,L)/BULKDENS(1:KB,L))
    THCK(L)=TSEDT(L)-TSET0T(L)
ENDDO

! Create 2D arrays for all time variable parameters
DO J=3,JC-2
   DO I=3,IC-2
      IF(LIJ(I,J)>0) THEN
        L=LIJ(I,J)
        
        ! Initialize temp. velocity variables
        utmpa=0.0
        vtmpa=0.0
        
        IF(LMASKDRY(L).AND.HP(L).GT.0.3) THEN
        
            ! Calculate temp. velocities for each water layer
            DO K=1,KC
                utmps=U(L,K) ! m/s
                vtmps=V(L,K) 
                utmpa=utmps(L)*DZC(K)+utmpa
                vtmpa=vtmps(L)*DZC(K)+vtmpa
            ENDDO
         
            ! Cell max. velocity
            vel_magc(L)=SQRT(utmpa**2+vtmpa**2)
         
            IF(vel_magc(L).GT.vel_max(L)) THEN
                vel_max(L)=vel_magc(L)
            ENDIF

            !IF(TAU(L).GT.TAUMAX(L)) THEN
            !    TAUMAX(L)=TAU(L)
            !ENDIF
        ENDIF
        
        mask(J,I)=wet_dry_mask(LIJ(I,J))
        wl(J,I)=zeta(LIJ(I,J))
        u_2d(J,I)=U(LIJ(I,J),1)
        v_2d(J,I)=V(LIJ(I,J),1)
        mag(J,I)=vel_max(LIJ(I,J))
        shear(J,I)=TAU(LIJ(I,J))
        maxshear(J,I)=TAUMAX(LIJ(I,J))
        IF (ISTRAN(1).EQ.1) salt(J,I)=SAL(LIJ(I,J),1)
        IF (ISTRAN(3).EQ.1) dye_2d(J,I)=DYE(LIJ(I,J),1)
        IF (ISTRAN(6).EQ.1) THEN
            grain_size(J,I)=D50AVG(LIJ(I,J))
            sed_thick(J,I)=THCK(LIJ(I,J))
            DO S=1,NSCM
                tss(J,I,S)=SED(LIJ(I,J),1,S)
                DO T=1,KB
                    perc_sed(J,I,S,T)=PER(S,T,LIJ(I,J))
                ENDDO
            ENDDO
            DO S=1,KB
                sed_mass(J,I,S)=TSED(S,LIJ(I,J))
            ENDDO
            e_rate(J,I)=ETOTO(LIJ(I,J))
            tau_crit(J,I)=TAUCRIT(LIJ(I,J))
            !vz_dif(J,I)=VZDIF(LIJ(I,J))
        ENDIF
      ELSE
        ! Flag for inactive cells
        mask(J,I)=-7999.
        wl(J,I)=-7999.
        u_2d(J,I)=-7999.
        v_2d(J,I)=-7999.
        mag(J,I)=-7999.
        shear(J,I)=-7999.
        maxshear(J,I)=-7999.
        IF (ISTRAN(1).EQ.1) salt(J,I)=-7999.
        IF (ISTRAN(3).EQ.1) dye_2d(J,I)=-7999.
        IF (ISTRAN(6).EQ.1) THEN
            grain_size(J,I)=-7999.
            sed_thick(J,I)=-7999.
            DO S=1,NSCM
               tss(J,I,S)=-7999.
                DO T=1,KB
                    perc_sed(J,I,S,T)=-7999.
                ENDDO
            ENDDO
            DO S=1,KB
                sed_mass(J,I,S)=-7999.
            ENDDO
            e_rate(J,I)=-7999.
            tau_crit(J,I)=-7999.
            !vz_dif(J,I)=-7999.
        ENDIF
      ENDIF
   ENDDO
ENDDO

! Open NetCDF file
status=nf90_open(FILE_NAME, nf90_write, ncid)
if(status /= nf90_NoErr) call handle_err(status)

!*************************************************************************************
! Put time stepped variables into file

! Put EFDC times into file
status=nf90_put_var(ncid, time_varid, time_efdc, start=start)
if(status /= nf90_NoErr) call handle_err(status)

! Put wet dry mask into file
status=nf90_put_var(ncid,mask_varid,mask,start=start_3d)
if(status /= nf90_NoErr) call handle_err(status)

! Put surface elevations into file
status=nf90_put_var(ncid,surfel_varid,wl,start=start_3d)
if(status /= nf90_NoErr) call handle_err(status)

! Put u components into file
status=nf90_put_var(ncid,u_varid,u_2d,start=start_3d)
if(status /= nf90_NoErr) call handle_err(status)

! Put v components into file
status=nf90_put_var(ncid,v_varid,v_2d,start=start_3d)
if(status /= nf90_NoErr) call handle_err(status)

!Put max. velocity into file
status=nf90_put_var(ncid,vmax_varid,mag,start=(/1,1,1/))
if(status /= nf90_NoErr) call handle_err(status)

! Put shear stress into file
status=nf90_put_var(ncid,tau_varid,shear,start=start_3d)
if(status /= nf90_NoErr) call handle_err(status)

! Put max. shear stress into file
status=nf90_put_var(ncid,taumax_varid,maxshear,start=(/1,1,1/))
if(status /= nf90_NoErr) call handle_err(status)

IF (ISTRAN(1).EQ.1) THEN
    ! Put salinity into file
    status=nf90_put_var(ncid,sal_varid,salt,start=start_3d)
    if(status /= nf90_NoErr) call handle_err(status)
ENDIF

IF (ISTRAN(3).EQ.1) THEN
    ! Put dye into file
    status=nf90_put_var(ncid,dye_varid,dye_2d,start=start_3d)
    if(status /= nf90_NoErr) call handle_err(status)
ENDIF

IF (ISTRAN(6).EQ.1) THEN
    ! Put TSS into file
    status=nf90_put_var(ncid,tss_varid,tss,start=start_4d)
    if(status /= nf90_NoErr) call handle_err(status)

    ! Put D50 into file
    status=nf90_put_var(ncid,d50_varid,grain_size,start=start_3d)
    if(status /= nf90_NoErr) call handle_err(status)

    ! Put sediment thickness into file
    status=nf90_put_var(ncid,thick_varid,sed_thick,start=start_3d)
    if(status /= nf90_NoErr) call handle_err(status)

    ! Put total erosion rate into file
    status=nf90_put_var(ncid,erate_varid,e_rate,start=start_3d)
    if(status /= nf90_NoErr) call handle_err(status)

    ! Put bed critical shear stress into file
    status=nf90_put_var(ncid,taucrit_varid,tau_crit,start=start_3d)
    if(status /= nf90_NoErr) call handle_err(status)
    
    ! Put vertical diffusivity
    !status=nf90_put_var(ncid,vzdif_varid,vz_dif,start=start_3d)
    !if(status /= nf90_NoErr) call handle_err(status)

    ! Put cell sediment mass into file
    status=nf90_put_var(ncid,tsed_varid,sed_mass,start=start_4d)
    if(status /= nf90_NoErr) call handle_err(status)

    ! Put percent of sediment size class into file
    status=nf90_put_var(ncid,psed_varid,perc_sed,start=start_5d)
    if(status /= nf90_NoErr) call handle_err(status)
ENDIF

! Close NetCDF file each time
status=nf90_close(ncid)
if(status /= nf90_NoErr) call handle_err(status)


CONTAINS
    SUBROUTINE handle_err(status)
        INTEGER, INTENT ( in) :: status

        IF(status /= nf90_noerr) THEN
            PRINT *, TRIM(nf90_strerror(status))
            STOP 'Stopped'
        END IF
    END SUBROUTINE handle_err
END SUBROUTINE netcdf_write
