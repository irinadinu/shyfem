c
c $Id: noselab.f,v 1.8 2008-11-20 10:51:34 georg Exp $
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
c 05.10.2015    ggu     variables in xv were used in the wromg order - fixed
c 05.10.2017    ggu     implement quiet, silent option, write dir
c 09.10.2017    ggu     consistent treatment of output files
c
c**************************************************************

	subroutine extelab

	use clo
	use elabutil
	use elabtime

        use basin
        use mod_depth
        use evgeom
        use levels

c elaborates nos file

	implicit none

	integer, parameter :: niu = 6

	integer, allocatable :: knaus(:)
	real, allocatable :: hdep(:)
	real, allocatable :: xv(:,:)
	real, allocatable :: speed(:)
	real, allocatable :: dir(:)

	integer, allocatable :: naccu(:)
	double precision, allocatable :: accum(:,:,:)

	logical blastrecord
	integer nread,nelab,nrec,nin
	integer nvers
	integer nknnos,nelnos,nvar
	integer ierr
	integer it,ivar,itvar,itnew,itold,iaux
	integer itfirst,itlast
	integer ii,i,j,l,k,lmax,node
	integer ip,nb,naccum
	integer knausm
	integer date,time
	character*80 title,name,file
	character*20 dline
	character*80 basnam,simnam
	real rnull
	real cmin,cmax,cmed,vtot
	real zmin,zmax,zmed
	real href,hzmin
	real s,d
	!character*1 :: what(niu) = (/'u','v','z','m','d','a'/)
	character*5 :: what(niu) = (/'velx ','vely ','zeta '
     +				,'speed','dir  ','all  '/)
	character*23 :: descrp(niu) = (/
     +		 'velocity in x-direction'
     +		,'velocity in y-direction'
     +		,'water level            '
     +		,'current speed          '
     +		,'current direction      '
     +		,'all variables          '
     +			/)

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

	call elabutil_init('EXT','extelab')

	!--------------------------------------------------------------
	! open input files
	!--------------------------------------------------------------

	call clo_reset_files
	call clo_get_next_file(file)
	nin = ifileo(0,file,'unform','old')

        call ext_is_ext_file(nin,nvers)
        if( nvers .le. 0 ) then
          write(6,*) 'nvers: ',nvers
          stop 'error stop extelab: not a valid ext file'
        end if

	call ext_peek_header(nin,nvers,knausm)
	nlv = 1

	allocate(knaus(knausm))
	allocate(hdep(knausm))
	allocate(xv(knausm,3))
	allocate(speed(knausm))
	allocate(dir(knausm))

	call ext_read_header(nin,knausm,nvers,knausm,knaus,hdep
     +                          ,href,hzmin,title)

	if( .not. bquiet ) then
          write(6,*) 'nvers      : ',nvers
          write(6,*) 'knausm     : ',knausm
          write(6,*) 'href,hzmin : ',href,hzmin
          write(6,*) 'title      : ',trim(title)
          write(6,*) 'knaus      : '
          write(6,*) (knaus(i),i=1,knausm)
          write(6,*) 'hdep       : '
          write(6,*) (hdep(i),i=1,knausm)
	end if

	if( binfo ) return

	!--------------------------------------------------------------
	! time management
	!--------------------------------------------------------------

	!call nos_get_date(nin,date,time)
	date = 0
	time = 0
	call elabtime_date_and_time(date,time)

	call ext_peek_record(nin,nvers,itfirst,ierr)
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
	  nb = ifileo(0,'out.ext','unform','new')
	  call ext_write_header(nb,knausm,nvers,knausm,knaus,hdep
     +                          ,href,hzmin,title)
	end if

c--------------------------------------------------------------
c loop on data
c--------------------------------------------------------------

	it = 0
	if( .not. bquiet ) write(6,*)
	blastrecord = .false.

	do

	 if( blastrecord ) exit
	 itold = it

	 call ext_read_record(nin,nvers,it,knausm,xv,ierr)
         if(ierr.gt.0) write(6,*) 'error in reading file : ',ierr
         if(ierr.ne.0) exit
	 nread=nread+1

         if(ierr.ne.0) exit
	 nrec = nrec + 1

	 itlast = it
	 if( nrec == 1 ) itold = it
	 call ext_peek_record(nin,nvers,itnew,ierr)
	 !write(6,*) 'peek: ',it,itnew,ierr
	 if( ierr .ne. 0 ) itnew = it
	 if( ierr < 0 ) blastrecord = .true.

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
	        call mimar(xv(:,ii),knausm,zmin,zmax,rnull)
                call aver(xv(:,ii),knausm,zmed,rnull)
	        write(6,*) what(ii),' min,max,aver : ',zmin,zmax,zmed
	      end do
	      do ii=1,knausm
	        !speed(ii) = sqrt( xv(ii,1)**2 + xv(ii,2)**2 )
	        call c2p(xv(ii,1),xv(ii,2),s,d)
		d = d + 180.
                if( d > 360. ) d = d - 360.
		speed(ii) = s
		dir(ii) = d
	      end do
	      call mimar(speed,knausm,zmin,zmax,rnull)
              call aver(speed,knausm,zmed,rnull)
	      write(6,*) what(4),' min,max,aver : ',zmin,zmax,zmed
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
            call split_xv(it,knausm,what,xv)
	  end if

	  if( boutput ) then
	    if( bverb ) write(6,*) 'writing to output: ',ivar
            call ext_write_record(nb,nvers,it,knausm,xv)
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
	  do i=1,niu
	      write(6,*) '  '//descrp(i)//'  '//trim(what(i))//'.*'
	  end do
	 else if( boutput ) then
	  write(6,*) 'output written to file out.ext'
	 end if
	end if

	!if( .not. bquiet ) then
	! call ap_get_names(basnam,simnam)
	! write(6,*) 'names used: '
	! write(6,*) '  simul: ',trim(simnam)
	!end if

c--------------------------------------------------------------
c end of routine
c--------------------------------------------------------------

	return
   85	continue
	write(6,*) 'it,itvar,i,ivar,nvar: ',it,itvar,i,ivar,nvar
	stop 'error stop extelab: time mismatch'
   91	continue
	write(6,*) 'error reading first data record'
	write(6,*) 'maybe the file is empty'
	stop 'error stop extelab: empty record'
   99	continue
	write(6,*) 'error writing to file unit: ',nb
	stop 'error stop extelab: write error'
	end

c***************************************************************
c***************************************************************
c***************************************************************

        subroutine split_xv(it,knausm,what,xv)

        implicit none

	integer, parameter :: niu = 6
	integer it
        integer knausm
        character*5 what(niu)
        real xv(knausm,3)

	integer j,ii,iu
	real s,d
        character*80 name
        character*70 numb
	integer, save, allocatable :: iusplit(:,:)
	integer, save :: icall = 0

	iu = 100

	if( icall == 0 ) then
	  allocate(iusplit(niu,knausm))
	  iusplit = 0
	  do j=1,knausm
	    do ii=1,niu
	      call make_iunit_name(what(ii),'','2d',j,iu)
	      iusplit(ii,j) = iu
	    end do
	  end do
	end if

	icall = icall + 1

	do j=1,knausm
	  do ii=1,3
	    iu = iusplit(ii,j)
	    write(iu,*) it,xv(j,ii)
	  end do
	  call c2p_ocean(xv(j,1),xv(j,2),s,d)
	  iu = iusplit(4,j)
	  write(iu,*) it,s
	  iu = iusplit(5,j)
	  write(iu,*) it,d
	  iu = iusplit(6,j)
	  write(iu,'(i12,5f12.4)') it,xv(j,3),xv(j,1),xv(j,2),s,d
	end do

        end

c***************************************************************

