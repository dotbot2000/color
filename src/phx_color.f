CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C       PHOENIX COLOR INTERPOLATION IN TEFF, LOG G, [Fe/H],& [a/Fe]    C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
C                                                                      C
CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC

ccccccccccccccccccccccc subroutine phx_color_init cccccccccccccccccccccc
c this subroutine determines which filter set will be used, reads in   c
c the appropriate tables, and stores them in coltbl                    c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      module phoenix
      
      implicit none
      
      integer, parameter :: nz_max=10
      integer, parameter :: nt=66, nfl=14, nmax=1000, phx_file=21,pnc=90
      double precision, parameter :: cln = dlog(1.0d1)
      double precision :: z(nz_max),coltbl(pnc,nmax,nz_max),teff(nz_max,nmax),ggl(nz_max,nmax)
      integer :: itemp(nz_max,nt),itnum(nz_max),isize(nz_max),pcol(nfl)
      integer :: pncol,nz,tintp=4,gintp=4,zintp=4
      logical :: phx_initialized = .false., phx_debug = .false.
      character(len=12) :: phx_filters(pnc)
      character(len=128) :: phx_data_dir

      contains

      subroutine phx_color_init(data_dir,afe,filter)
      character(len=128) :: data_dir
      double precision, intent(in) :: afe
      integer, intent(in) :: filter
      integer :: iafe

      phx_data_dir = trim(data_dir) // '/phx/'

      pcol(:) = (/10,10,13,12,17,77,5,5,7,4,5,4,6,6/)
      z(:) = (/-4.0d0,-3.5d0,-3.0d0,-2.5d0,-2.0d0,-1.5d0,-1.0d0,-0.5d0,
     *     0.0d0,0.5d0/)

      pncol = pcol(filter)

      if(afe.gt.0.2d0) then
         nz=9
      else
         nz=10
      endif

c filter is an integer representing the choice of filter set
c options include:
c     1. Bessell UBV(RI)c + 2MASS JHKs + Kepler Kp and D51
c     2. Washington + DDO51 + Stromgren
c     3. HST-WFPC2
c     4. HST-ACS WFC
c     5. HST-ACS HRC
c     6. HST-WFC3 UVIS+IR
c     7. CFHT ugriz
c     8. SDSS ugriz
c     9. PanSTARRS
c    10. Spitzer IRAC
c    11. UKIDSS
c    12. WISE

c set [a/Fe] index parameter
      iafe=0
      if(afe.eq.-0.2d0) iafe=1
      if(afe.eq. 0.0d0) iafe=2
      if(afe.eq. 0.2d0) iafe=3
      if(afe.eq. 0.4d0) iafe=4
      if(afe.eq. 0.6d0) iafe=5
      if(afe.eq. 0.8d0) iafe=6
      !if(feh.le.-2.5d0) iafe=2
      if(iafe.eq.0) stop "PROBLEM WITH [a/Fe] IN ISOCHRONE FILE"

c read in the required tables for a range of [Fe/H] at fixed [a/Fe]    
      call phx_color_read(iafe,filter)

      phx_initialized = .true.
c all set for interpolation in T_eff and log(g)      
      end subroutine phx_color_init

ccccccccccccccccccccccccc subroutine phx_color_read ccccccccccccccccccccccc
c reads in color tables based on specified Z, [a/Fe], filter set          c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine phx_color_read(iafe,filter)

      integer :: iafe,filter,iz,ia,j,ierr
      double precision :: feh0
      character(len=128) :: filename
      character(len=5) :: zfile(nz_max)
      character(len=3) :: afile(6)
      character(len=11) :: suffix(nfl)

      suffix = (/ 'UBVRIJHKsKp', 'WashDDOuvby', 'HST_WFPC2  ', 'HST_ACSWF  ',
     >            'HST_ACSHR  ', 'HST_WFC3   ', 'CFHTugriz  ', 'SDSSugriz  ',
     >            'PanSTARRS  ', 'SPITZER    ', 'UKIDSS     ', 'WISE       ',
     >            'SkyMapper  ', 'LSST       '                              /)
      afile(:) = (/'am2','ap0','ap2','ap4','ap6','ap8'/)
      zfile(:) = (/'Zm4d0','Zm3d5','Zm3d0','Zm2d5','Zm2d0','Zm1d5',
     *     'Zm1d0','Zm0d5','Zp0d0','Zp0d5'/)

      do iz=1,nz
c set up filenames based on the input variables
         if(iz<4)then
            ia = 2
         else
            ia=iafe
         endif
         filename = trim(phx_data_dir) // zfile(iz) // afile(ia) // 
     >        "." // suffix(filter)
         if(phx_debug) write(0,*) trim(filename)
c open table for reading
         open(phx_file,file=trim(filename),status='old')
         read(phx_file,'(17x,99a12)',iostat=ierr) phx_filters(1:pncol)
         read(phx_file,*,iostat=ierr) !skip this line
c read data in table
         do j=1,nmax
            read(phx_file,*,iostat=ierr)
     *           teff(iz,j),ggl(iz,j),feh0,coltbl(1:pncol,j,iz)
            if(ierr/=0) exit
            if(feh0/=z(iz)) write(0,*) 'WARNING: table [Fe/H] incorrect'
         enddo
c close data file
         close(phx_file)
c isize counts number of data points, itnum counts number of distinct T's,
c itemp gives location of each T value in the teff-array
         isize(iz)=j-1
         itemp(iz,1)=1
         itnum(iz)=1
         do j=2,isize(iz)
            if(teff(iz,j).gt.teff(iz,j-1)) then
               itnum(iz)=itnum(iz)+1
               itemp(iz,itnum(iz))=j
            endif
         enddo
      enddo
      
      end subroutine phx_color_read

ccccccccccccccccccccccc subroutine phx_color_interp ccccccccccccccccccccc
c     interpolates the mags and colors based on T, g, [Fe/H], [a/Fe]    c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine phx_color_interp(feh,tl0,gl0,color)

      double precision, intent(in) :: feh, tl0, gl0
      double precision, intent(out) :: color(pnc)
      integer :: i,j,k,iii,jj,inewt,inewg,iz,izlo,izhi
      double precision :: fg(4),ft(4),tl,gl,t,qt(4),qg(4),colr(nz_max,pnc),col(nz_max,pnc,4),fz(4)
      double precision :: feh0

      iz=0
      tl=tl0
      gl=gl0
      t=dexp(cln*tl)
      if(gl.ge.5.5d0) gl=5.4999d0
      !if(gl.le.0d0) gl=0d0
      inewt=0
      inewg=0

      tintp=4
      gintp=4

      feh0 = min(feh,z(nz)-1d-3)
      if(phx_debug) write(0,*) 'phx: ', feh, feh0, z(nz)


c     [Fe/H] interpolation
      do i=1,nz-1
         if( feh0>=z(i) .and. feh0<z(i+1) ) iz=i
      enddo
      if(iz<zintp/2) iz=zintp/2
      if(iz>nz-zintp/2) iz=nz-zintp/2

      izlo=iz+1-zintp/2
      izhi=iz+zintp/2
      call phx_interp(z(izlo:izhi),fz,feh0,4)

      do iii=izlo,izhi
c     locate T in the Teff array (default is linear interpolation in T)
         do i=1,itnum(iii)-1
            if(t.ge.teff(iii,itemp(iii,i)).and.
     *           t.lt.teff(iii,itemp(iii,i+1))) inewt=i
         enddo
         if(inewt.lt.tintp/2) then
            tintp=2
            inewt=tintp/2
         elseif(inewt.gt.itnum(iii)-tintp/2) then
            tintp=2
            inewt=itnum(iii)-tintp/2
         endif
c     find interpolation coeff.'s in T
         do i=1,tintp
            qt(i)=teff(iii,itemp(iii,inewt+i-tintp/2))
         enddo
         call phx_interp(qt,ft,t,tintp)

         if(phx_debug)then
            print *, 'iz, izlo, izhi, z(iz)=', iz, izlo, izhi, z(iz)
            write(*,'(a20,3f12.4)') 'Teff, logg, [Fe/H]=', t, gl, feh
            write(*,'(a20,1p4e12.4)') 'fz(:)=', fz
            write(*,'(a20,1p4e12.4)') 'qt(:)=', qt
            write(*,'(a20,1p4e12.4)') 'ft(:)=', ft
         endif


c  locate Log G for each T (default is quadratic interpolation in log g)
         do j=1,tintp
            jj=inewt+j-tintp/2
            do k=itemp(iii,jj),itemp(iii,jj+1)-1
               if(gl.ge.ggl(iii,k).and.gl.lt.ggl(iii,k+1)) inewg=k
            enddo

            if(inewg.lt.itemp(iii,jj)+gintp/2)then
               gintp=2
               inewg=itemp(iii,jj)+gintp/2
            elseif(inewg.gt.itemp(iii,jj+1)-1-gintp/2) then
               gintp=2
               inewg=itemp(iii,jj+1)-1-gintp/2
            endif

            !if(.true.) write(*,'(a30,3f12.4,i4)') '  t, gl, gl0, inewg = ', t, gl, gl0, inewg

c     find interpolation coefficients in Log G
            do k=1,gintp
               qg(k)=ggl(iii,inewg+k-gintp/2)
            enddo
            call phx_interp(qg,fg,gl,gintp)

c     g-interpolation
            do k=1,pncol
               col(iii,k,j)=0.0d0
               do i=1,gintp
                  col(iii,k,j)=col(iii,k,j) + 
     *                 fg(i)*coltbl(k,inewg+i-gintp/2,iii)
               enddo            !i-loop
            enddo               !k-loop
         enddo                  !j-loop

c     T-interpolation
         do i=1,pncol
            colr(iii,i)=0.0d0
            do j=1,tintp
               colr(iii,i)=colr(iii,i)+ft(j)*col(iii,i,j)
            enddo               !j-loop
         enddo                  !i-loop
        
      enddo                     !iii-loop

c     Z-interpolation
      do i=1,pncol
         color(i)=0.0d0
         do j=1,zintp
            color(i)=color(i)+fz(j)*colr(iz-zintp/2+j,i)
         enddo
      enddo

      if(phx_debug)then
         do i=1,pncol
            write(*,'(a20,i3,5f12.6)') 'i, color(i)=', i, color(i), colr(izlo:izhi,i)
         enddo
      endif

      end subroutine phx_color_interp

C************************************************************************
C               N-PT. Lagrangian Interpolation Coefficients
C************************************************************************
      subroutine phx_interp(a,b,x,n)
c {a} are the tabulated values for use in interpolation
c {b} are coefficients of the interpolating polynomial
c  x  is the abscissa to be interpolated
c  n  is the number of points to be used, interpolating polynomial
c     has order n-1 
      integer, intent(in) :: n
      double precision, intent(in) :: a(n), x
      double precision, intent(out) :: b(n)
      integer :: i,j
      do i=1,n
         b(i)=1.0d0
         do j=1,n
            if(j.ne.i) b(i)=b(i)*(x-a(j))/(a(i)-a(j))
         enddo
      enddo

      end subroutine phx_interp
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c                           END of PHX_COLOR.F                          c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      end module phoenix
