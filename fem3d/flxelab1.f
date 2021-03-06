c
c $Id: flxelab.f,v 1.8 2008-11-20 10:51:34 georg Exp $
c
c revision log :
c
c 18.11.1998    ggu     check dimensions with dimnos
c 06.04.1999    ggu     some cosmetic changes
c 03.12.2001    ggu     some extra output -> place of min/max
c 09.12.2003    ggu     check for NaN introduced
c 07.03.2007    ggu     easier call
c 08.11.2008    ggu     do not compute min/max in non-existing layers
c 07.12.2010    ggu     write statistics on depth distribution (depth_stats)
c 06.05.2015    ggu     noselab started
c 05.06.2015    ggu     many more features added
c 05.10.2015    ggu     started flxelab
c
c**************************************************************

	subroutine flxelab

	use clo
	use elabutil
	use elabtime

        use basin
        use mod_depth
        use evgeom
        use levels

c elaborates flx file

	implicit none

	integer, allocatable :: kflux(:)
	integer, allocatable :: nlayers(:)
	real, allocatable :: fluxes(:,:,:)

	integer, allocatable :: naccu(:)
	double precision, allocatable :: accum(:,:,:)

	logical b3d
	integer nread,nelab,nrec,nin
	integer nvers
	integer nknnos,nelnos,nvar
	integer ierr
	integer it,ivar,itvar,itnew,itold,iaux
	integer itfirst,itlast
	integer ii,i,j,l,k,lmax,node
	integer ip,nb,naccum
	integer kfluxm
	integer idtflx,nlmax,nsect
	integer nscdi,nfxdi
	integer date,time
	character*80 title,name
	character*20 dline
	character*80 basnam,simnam
	real rnull
	real cmin,cmax,cmed,vtot
	real zmin,zmax,zmed
	real href,hzmin
	character*1 :: what(5) = (/'u','v','z','m','a'/)
	character*80 file

	integer iapini,ifileo
	integer ifem_open_file

c--------------------------------------------------------------

	nread=0
	nelab=0
	nrec=0
	rnull=0.
	rnull=-1.
	bopen = .false.

c--------------------------------------------------------------
c set command line parameters
c--------------------------------------------------------------

	call elabutil_init('FLX','flxelab')

	!--------------------------------------------------------------
	! open input files
	!--------------------------------------------------------------

        call clo_reset_files
        call clo_get_next_file(file)
        nin = ifileo(0,file,'unform','old')

        call flx_is_flx_file(nin,nvers)
        if( nvers .le. 0 ) then
          write(6,*) 'nvers: ',nvers
          stop 'error stop flxelab: not a valid flx file'
        end if

	call flx_peek_header(nin,nvers,nsect,kfluxm,nlmax)
	nscdi = nsect
	nfxdi = kfluxm
	nlvdi = nlmax
	nlv = nlmax

	allocate(kflux(kfluxm))
	allocate(nlayers(nscdi))
	allocate(fluxes(0:nlvdi,3,nscdi))

        call flx_read_header(nin,nscdi,nfxdi,nlvdi
     +                          ,nvers
     +                          ,nsect,kfluxm,idtflx,nlmax
     +                          ,kflux,nlayers
     +                          )

	if( .not. bquiet ) then
          write(6,*) 'nvers      : ',nvers
          write(6,*) 'nsect      : ',nsect
          write(6,*) 'kfluxm     : ',kfluxm
          write(6,*) 'idtflx     : ',idtflx
          write(6,*) 'nlmax      : ',nlmax
          write(6,*) 'kflux      : '
          write(6,*) (kflux(i),i=1,kfluxm)
          write(6,*) 'nlayers       : '
          write(6,*) (nlayers(i),i=1,nsect)
	end if

	if( binfo ) return

	b3d = nlmax > 1

	!--------------------------------------------------------------
	! time management
	!--------------------------------------------------------------

	!call nos_get_date(nin,date,time)
	date = 0
	time = 0
	call elabtime_date_and_time(date,time)

	call flx_peek_record(nin,nvers,itfirst,ierr)
	if( ierr /= 0 ) goto 91

	!--------------------------------------------------------------
	! averaging
	!--------------------------------------------------------------

	!call elabutil_set_averaging(nvar)

	btrans = .false.
	if( btrans ) then
	  allocate(naccu(istep))
	  allocate(accum(nlvdi,nkn,istep))
	else
	  allocate(naccu(1))
	  allocate(accum(1,1,1))
	end if
	naccum = 0
	naccu = 0
	accum = 0.

	!write(6,*) 'mode: ',mode,ifreq,istep

	!--------------------------------------------------------------
	! open output file
	!--------------------------------------------------------------

	boutput = boutput .or. btrans
	bopen = boutput
	if( bsplit ) then
	  boutput = .false.
	  bopen = .false.
	end if

	if( bopen ) then
	  nb = ifileo(0,'out.flx','unform','new')
	  call flx_write_header(nb,nvers,nsect,kfluxm
     +			,idtflx,nlmax,kflux,nlayers)
	end if

c--------------------------------------------------------------
c loop on data
c--------------------------------------------------------------

	it = 0
	if( .not. bquiet ) write(6,*)

	do

	 itold = it

	 call flx_read_record(nin,nvers,it,nlvdi,nsect,ivar
     +			,nlayers,fluxes,ierr)
         if(ierr.gt.0) write(6,*) 'error in reading file : ',ierr
         if(ierr.ne.0) exit
	 nread=nread+1

         if(ierr.ne.0) exit
	 nrec = nrec + 1

	 itlast = it
	 if( nrec == 1 ) itold = it
	 call flx_peek_record(nin,nvers,itnew,ierr)
	 !write(6,*) 'peek: ',it,itnew,ierr
	 if( ierr .ne. 0 ) itnew = it

	 if( .not. elabtime_check_time(it,itnew,itold) ) cycle

	  nelab=nelab+1

	  if( .not. bquiet ) then
	    dline = ' '
	    if( bdate ) call dtsgf(it,dline)
	    write(6,*) 'time : ',it,'  ',dline
	  end if

	  if( bwrite ) then
	    do l=1,nlv
	      do ii=1,3
	        !call mimar(xv(ii,:),kfluxm,zmin,zmax,rnull)
                !call aver(xv(ii,:),kfluxm,zmed,rnull)
	        !write(6,*) what(ii),' min,max,aver : ',zmin,zmax,zmed
	      end do
	      !do ii=1,kfluxm
	      !  s(ii) = sqrt( xv(1,ii)**2 + xv(2,ii)**2 )
	      !end do
	      !call mimar(s,kfluxm,zmin,zmax,rnull)
              !call aver(s,kfluxm,zmed,rnull)
	      !write(6,*) what(4),' min,max,aver : ',zmin,zmax,zmed
	    end do
	  end if

	  if( btrans ) then
!	    call nos_time_aver(mode,i,ifreq,istep,nkn,nlvdi
!     +					,naccu,accum,cv3,boutput)
	  end if

	  if( baverbas ) then
!	    call make_aver(nlvdi,nkn,ilhkv,cv3,vol3
!     +                          ,cmin,cmax,cmed,vtot)
!	    call write_aver(it,ivar,cmin,cmax,cmed,vtot)
	  end if

	  if( b2d ) then
	    !call make_vert_aver(nlvdi,nkn,ilhkv,cv3,vol3,cv2)
	  end if

	  if( bsplit ) then
            call split_flx(it,nlvdi,nsect,ivar,fluxes)
            call fluxes_2d(it,nlvdi,nsect,ivar,fluxes)
	    if( b3d ) then
	      call fluxes_3d(it,nlvdi,nsect,ivar,nlayers,fluxes,bsplitflx)
	    end if
	  end if

	  if( boutput ) then
	    if( bverb ) write(6,*) 'writing to output: ',ivar
            call flx_write_record(nb,nvers,it
     +			,nlvdi,nsect,ivar,nlayers,fluxes)	!FIXME
	  end if

	end do		!time do loop

c--------------------------------------------------------------
c end of loop on data
c--------------------------------------------------------------

c--------------------------------------------------------------
c final write of variables
c--------------------------------------------------------------

	if( btrans ) then
	  !write(6,*) 'istep,naccu: ',istep,naccu
	  do ip=1,istep
	    naccum = naccu(ip)
	    !write(6,*) 'naccum: ',naccum
	    if( naccum > 0 ) then
	      write(6,*) 'final aver: ',ip,naccum
!	      call nos_time_aver(-mode,ip,ifreq,istep,nkn,nlvdi
!     +					,naccu,accum,cv3,boutput)
!	      if( bsumvar ) ivar = 30
!              call nos_write_record(nb,it,ivar,nlvdi,ilhkv,cv3,ierr)
              if( ierr .ne. 0 ) goto 99
	    end if
	  end do
	end if

c--------------------------------------------------------------
c write final message
c--------------------------------------------------------------

	if( .not. bsilent ) then
          write(6,*)
          call dtsgf(itfirst,dline)
          write(6,*) 'first time record: ',dline
          call dtsgf(itlast,dline)
          write(6,*) 'last time record:  ',dline
	  write(6,*)
	  write(6,*) nread,' records read'
	  !write(6,*) nrec ,' unique time records read'
	  write(6,*) nelab,' records elaborated'
	  write(6,*)
	end if

	if( .not. bquiet ) then
	 if( bsplit ) then
	  write(6,*) 'output written to following files: '
	  write(6,*) '   p.[1-9]'
	 else if( boutput ) then
	  write(6,*) 'output written to file out.flx'
	 end if
	end if

	!call ap_get_names(basnam,simnam)
	!write(6,*) 'names used: '
	!write(6,*) 'simul: ',trim(simnam)

c--------------------------------------------------------------
c end of routine
c--------------------------------------------------------------

	stop
   85	continue
	write(6,*) 'it,itvar,i,ivar,nvar: ',it,itvar,i,ivar,nvar
	stop 'error stop flxelab: time mismatch'
   91	continue
	write(6,*) 'error reading first data record'
	write(6,*) 'maybe the file is empty'
	stop 'error stop flxelab: empty record'
   99	continue
	write(6,*) 'error writing to file unit: ',nb
	stop 'error stop flxelab: write error'
	end

c***************************************************************
c***************************************************************
c***************************************************************


c***************************************************************

        subroutine fluxes_2d(it,nlvddi,nsect,ivar,fluxes)

c writes 2d fluxes to file (only for ivar=0)

        implicit none

        integer it                      !time
        integer nlvddi                  !vertical dimension
        integer nsect                   !total number of sections
        integer ivar                    !type of variable (0: water fluxes)
        real fluxes(0:nlvddi,3,nsect)   !fluxes

        integer i,j,iu
        real ptot(4,nsect)
	character*80 name
        integer, save, allocatable :: iusplit(:)
        integer, save :: iubox = 0
        integer, save :: icall = 0

        if( ivar .ne. 0 ) return

        iu = 200

        if( icall == 0 ) then
	  allocate(iusplit(nsect))
	  iusplit = 0
	  do j=1,nsect
            call make_iunit_name('disch','','2d',j,iu)
            iusplit(j) = iu
          end do
          name = 'disch_box.2d.txt'
          iubox = iu + 1
          open(iubox,file=name,form='formatted',status='unknown')
        end if

	icall = icall + 1

        do j=1,nsect
          ptot(1,j) = fluxes(0,1,j)                     !total
          ptot(2,j) = fluxes(0,2,j)                     !positive
          ptot(3,j) = fluxes(0,3,j)                     !negative
          ptot(4,j) = fluxes(0,2,j) + fluxes(0,3,j)     !absolute
	  iu = iusplit(j)
	  write(iu,'(i12,4f16.4)') it,(ptot(i,j),i=1,4)
        end do

c next is box format for Ali

        write(iubox,*) it
        write(iubox,*) 0
        write(iubox,*) nsect
        do j=1,nsect
          write(iubox,*) 0,0,(ptot(i,j),i=1,3)
        end do

        end

c****************************************************************

        subroutine fluxes_3d(it,nlvddi,nsect,ivar,nlayers,fluxes,bext)

c writes 3d fluxes to file

	use shyfem_strings

        implicit none

        integer it                      !time
        integer nlvddi                  !vertical dimension
        integer nsect                   !total number of sections
        integer ivar                    !type of variable (0: water fluxes)
        integer nlayers(nsect)          !max layers for section
        real fluxes(0:nlvddi,3,nsect)   !fluxes
	logical bext			!extended write

        integer lmax,l,j,i
	integer iu,iunit
	integer, parameter :: ivarmax = 1000
	integer iuvar(0:ivarmax)
        integer, save, allocatable :: iusplit(:,:)
        integer, save :: iubase = 300
        integer, save :: icall = 0
	integer, save :: imin,imax
	real port(0:nlvddi,5,nsect)
	character*80 format
	character*10 short
	character*12, save :: what(5) = (/ 
     +				 'disch_total_'
     +				,'disch_plus_ '
     +				,'disch_minus_'
     +				,'disch_abs_  '
     +				,'disch_      '
     +				/)

        if( icall == 0 ) then
	  imin = 5
	  imax = 5
	  if( bext ) then		!write all fluxes, not only total
	    imin = 1
	    imax = 4
	  end if
	  iuvar = 0
	  allocate(iusplit(5,nsect))
	  iusplit = 0
	  iu = 0
	  do j=1,nsect
	    do i=imin,imax
	      iu = iu + 1
	      iusplit(i,j) = iu
	    end do
	  end do
	end if

	if( ivar > ivarmax ) goto 99

	if( iuvar(ivar) == 0 ) then
	  call strings_get_short_name(ivar,short)
	  iuvar(ivar) = iubase
	  iu = iubase
	  do j=1,nsect
	    do i=imin,imax
              call make_iunit_name(what(i),short,'3d',j,iu)
	    end do
          end do
	  iubase = iu
        end if

	icall = icall + 1

	if( bext ) then
	  port(:,1:3,:) = fluxes(:,1:3,:)
	  port(:,4,:) = fluxes(:,2,:)+fluxes(:,3,:)	!absolute
	else
	  port(:,5,:) = fluxes(:,1,:)			!equal to 1 (total)
	end if

        do j=1,nsect
          lmax = nlayers(j)
	  write(format,'(a,i3,a)') '(i12,',lmax,'f8.3)'
	  do i=imin,imax
	    iu = iuvar(ivar) + iusplit(i,j)
	    write(iu,format) it,(fluxes(l,i,j),l=1,lmax)
	  end do
        end do

	return
   99	continue
	write(6,*) 'ivar = ',ivar
	write(6,*) 'ivarmax = ',ivarmax
	write(6,*) 'please increase ivarmax'
	stop 'error stop fluxes_3d: ivarmax dimension'
        end

c****************************************************************

        subroutine split_flx(it,nlvddi,nsect,ivar,fluxes)

c writes data to file name.number

        implicit none

        integer it
	integer nlvddi
	integer nsect
	integer ivar
        real fluxes(0:nlvddi,3,nsect)   !fluxes

        integer j,iu
	integer, save :: icall = 0
        integer, save, allocatable :: iusplit(:)

        if( ivar .ne. 0 ) return

	iu = 100

	if( icall == 0 ) then
	  allocate(iusplit(nsect))
	  iusplit = 0
	  do j=1,nsect
	    call make_iunit_name('disch','','0d',j,iu)
	    iusplit(j) = iu
	  end do
	end if

	icall = icall + 1

	do j=1,nsect
	  iu = iusplit(j)
	  !write(iu,*) it,(fluxes(0,ii,j),ii=1,3)
	  write(iu,*) it,fluxes(0,1,j)
	end do

        end

c*******************************************************************


