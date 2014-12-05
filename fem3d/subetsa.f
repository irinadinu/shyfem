c
c $Id: subetsa.f,v 1.6 2001/11/16 07:35:43 georg Exp $
c
c ETS file administration routines (deals with section $EXTTS)
c
c revision log :
c
c 24.01.2014    ggu     copied from subexta.f
c
c******************************************************************

	subroutine mod_ets(mode)

	implicit none

	integer mode

	include 'modules.h'
	include 'femtime.h'

	if( mode .eq. M_AFTER ) then
	   call wretsa(it)
	else if( mode .eq. M_INIT ) then
	   call inetsa
	else if( mode .eq. M_READ ) then
	   call rdetsa
	else if( mode .eq. M_CHECK ) then
	   call cketsa
	else if( mode .eq. M_SETUP ) then
	   call wretsa(it)
	else if( mode .eq. M_PRINT ) then
	   call pretsa
	else if( mode .eq. M_TEST ) then
	   call tsetsa
	else if( mode .eq. M_BEFOR ) then
c	   nothing
	else
	   write(6,*) 'unknown mode : ', mode
	   stop 'error stop mod_ets'
	end if

	end

c******************************************************************

	subroutine inetsa

	implicit none

	include 'param.h'
	include 'subetsa.h'

	nets = 0

	end

c******************************************************************

	subroutine rdetsa

	implicit none

	include 'param.h'
	include 'subetsa.h'

	logical handlesec
	integer nrdtable

	if( .not. handlesec('extts') ) return

	nets = nrdtable(nkets,chets,nexdim)

	if( nets .lt. 0 ) then
	  if( nets .eq. -1 ) then
	    write(6,*) 'dimension error nexdim in section $extts : '
     +				,nexdim
	  else
	    write(6,*) 'read error in section $extts'
	    write(6,*) 'please remember that the format is:'
	    write(6,*) 'node  ''text'''
	    write(6,*) 'text may be missing'
	    write(6,*) 'only one node per line is allowed'
	  end if
	  stop 'error stop rdetsa'
	end if

	end

c******************************************************************

	subroutine cketsa

	implicit none

	include 'param.h'
	include 'subetsa.h'

	integer k,kext,kint
	integer ipint
	logical bstop

	bstop = .false.

        do k=1,nets
	   kext = nkets(k)
           kint = ipint(kext)
           if(kint.le.0) then
                write(6,*) 'section EXTTS : node not found ',kext
                bstop=.true.
           end if
           nkets(k)=kint
	   xets(k) = 0.
	   yets(k) = 0.
        end do

	if( bstop ) stop 'error stop: cketsa'

	end

c******************************************************************

	subroutine pretsa

	implicit none

	include 'param.h'
	include 'subetsa.h'

	integer i,k
	real x,y
	character*65 s
	integer ipext

        if(nets.le.0) return

        write(6,*)
        write(6,*) 'extts section: start ',nets
	do i=1,nets
	  k = ipext(nkets(i))
	  x = xets(i)
	  y = yets(i)
	  s = chets(i)
          write(6,1009) i,k,x,y,s(1:44)
          !write(6,1008) i,k,s
	end do
        write(6,*) 'extts section: end'
        write(6,*)

	return
 1009   format(i3,i7,2e12.4,1x,a)
 1008   format(i3,i10,1x,a)
	end

c******************************************************************

	subroutine tsetsa

	implicit none

	include 'param.h'
	include 'subetsa.h'

	integer i

        write(6,*) '/ets_/'
        write(6,*) nets
        write(6,*) (nkets(i),i=1,nets)
        write(6,*) (xets(i),i=1,nets)
        write(6,*) (yets(i),i=1,nets)
        write(6,*) (chets(i),i=1,nets)

	end

c******************************************************************
c******************************************************************
c******************************************************************

	subroutine wretsa(it)

c writes and administers ets file

	implicit none

	include 'param.h'
	include 'subetsa.h'
	include 'waves.h'

	integer it

	integer ierr
	integer date,time
	integer nvers,nvar,ivar
	character*80 title,femver
	real out(nlvdim,nexdim)

        character*80 descrp
        common /descrp/ descrp
        integer nkn,nel,nrz,nrq,nrb,nbc,ngr,mbw
        common /nkonst/ nkn,nel,nrz,nrq,nrb,nbc,ngr,mbw
        integer nlvdi,nlv
        common /level/ nlvdi,nlv
        integer ilhkv(1)
        common /ilhkv/ilhkv
        real hlv(1), hkv(1)
        common /hlv/hlv, /hkv/hkv

	real znv(1)
	common /znv/znv
	real uprv(nlvdim,1)
	common /uprv/uprv
	real vprv(nlvdim,1)
	common /vprv/vprv
	real saltv(nlvdim,1)
	common /saltv/saltv
	real tempv(nlvdim,1)
	common /tempv/tempv

	real waves(4,nkndim)

        integer il4kv(nkndim)

	integer ifemop
	real getpar
	double precision dgetpar
	logical has_output,next_output
	logical has_waves,bwave
	save bwave
	integer nvars

	integer nbext
	integer ia_out(4)
	save ia_out

	integer icall
	data icall /0/
	save icall

	if( icall .eq. -1 ) return

	if( icall .eq. 0 ) then
        	call init_output('itmext','idtext',ia_out)
        	if( .not. has_output(ia_out) ) icall = -1
		if( nets .le. 0 ) icall = -1

                if( icall .eq. -1 ) return

                nbext = ifemop('.ets','unformatted','new')
                if(nbext.le.0) goto 77
		ia_out(4) = nbext

		nvers = 1
		nvar = 5
	        bwave = has_waves()
	        if ( bwave ) nvar = nvar + 1

                date = nint(dgetpar('date'))
                time = nint(dgetpar('time'))
                title = descrp
                call get_shyfem_version(femver)

		call ets_setup

                call ets_init(nbext,nvers)
                call ets_set_title(nbext,title)
                call ets_set_date(nbext,date,time)
                call ets_set_femver(nbext,femver)
                call ets_write_header(nbext,nets,nlv,nvar,ierr)
                if(ierr.gt.0) goto 78
                call ets_write_header2(nbext,ilets,hlv,hets
     +					,nkets,xets,yets,chets,ierr)
                if(ierr.gt.0) goto 75
        end if

	icall = icall + 1

	if( .not. next_output(ia_out) ) return

	nbext =	ia_out(4)

	ivar = 1
	call routets(1,ilhkv,znv,out)
        call ets_write_record(nbext,it,ivar,1,ilets,out,ierr)
        if(ierr.ne.0.) goto 79

	if ( bwave ) then
  	  ivar = 31
	  nvars = 4
	  waves(1,:) = waveh
	  waves(2,:) = wavep
	  waves(3,:) = wavepp
	  waves(4,:) = waved
	  il4kv = nvars
	  call routets(nvars,il4kv,waves,out)
          call ets_write_record(nbext,it,ivar,nvars,ilets,out,ierr)
          if(ierr.ne.0.) goto 79
        end if

	ivar = 6
	call routets(nlvdim,ilhkv,uprv,out)
        call ets_write_record(nbext,it,ivar,nlvdim,ilets,out,ierr)
        if(ierr.ne.0.) goto 79

	ivar = 7
	call routets(nlvdim,ilhkv,vprv,out)
        call ets_write_record(nbext,it,ivar,nlvdim,ilets,out,ierr)
        if(ierr.ne.0.) goto 79

	ivar = 11
	call routets(nlvdim,ilhkv,saltv,out)
        call ets_write_record(nbext,it,ivar,nlvdim,ilets,out,ierr)
        if(ierr.ne.0.) goto 79

	ivar = 12
	call routets(nlvdim,ilhkv,tempv,out)
        call ets_write_record(nbext,it,ivar,nlvdim,ilets,out,ierr)
        if(ierr.ne.0.) goto 79

	return
   77   continue
	write(6,*) 'Error opening ETS file :'
	stop 'error stop : wretsa'
   75   continue
	write(6,*) 'Error writing second header of ETS file'
	write(6,*) 'unit,ierr :',nbext,ierr
	stop 'error stop : wretsa'
   78   continue
	write(6,*) 'Error writing first header of ETS file'
	write(6,*) 'unit,ierr :',nbext,ierr
	stop 'error stop : wretsa'
   79   continue
	write(6,*) 'Error writing file ETS'
	write(6,*) 'unit,ivar,ierr :',nbext,ivar,ierr
	stop 'error stop : wretsa'
	end

c******************************************************************

	subroutine ets_setup

	implicit none

	include 'param.h'
	include 'subetsa.h'

	integer i,k

        integer ilhkv(1)
        common /ilhkv/ilhkv
        real hkv(1)
        common /hkv/hkv
        real xgeov(1),ygeov(1)
	common /xgeov/xgeov, /ygeov/ygeov

	do i=1,nets
	  k = nkets(i)
	  ilets(i) = ilhkv(k)
	end do

	call routets(1,ilhkv,hkv,hets)
	call routets(1,ilhkv,xgeov,xets)
	call routets(1,ilhkv,ygeov,yets)

	end

c******************************************************************

	subroutine routets(nlv,ilhkv,value,out)

c extracts nodal information and stores it in array

	implicit none

	include 'param.h'
	include 'subetsa.h'

	integer nlv		!vertical dimension of data
	integer ilhkv(1)
	real value(nlv,1)
	real out(nlv,1)

	integer i,k,l,lmax

	do i=1,nets
	  k = nkets(i)
	  lmax = ilhkv(k)
	  lmax = min(lmax,nlv)
	  do l=1,lmax
	    out(l,i) = value(l,k)
	  end do
	end do

	end

c******************************************************************

