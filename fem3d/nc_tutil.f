
!=================================================================
	module nc_time
!=================================================================

	implicit none

	integer, save :: time_type
	integer, save :: date0
	double precision, save :: atime0
	double precision, save :: time_fact

!=================================================================
	end module nc_time
!=================================================================

c*****************************************************************

        subroutine setup_nc_time(ncid,bverb)

	use nc_time

	implicit none

	integer ncid
	logical bverb

	integer var_id
	integer ifact
	character*80 atext
	character*80 time_d,time_v

        call nc_get_time_name(time_d,time_v)
	call nc_get_var_id(ncid,time_v,var_id)
	call nc_get_var_attr(ncid,var_id,'units',atext)

	call parse_time_units(bverb,atext,time_type,date0,time_fact)

	call dtsini(date0,0)
	call dts_to_abs_time(date0,0,atime0)

	ifact = time_fact
	if( bverb ) write(6,*) 'setup_nc_time: '
     +					,date0,ifact,' ',trim(atext)

	end

c*****************************************************************

        subroutine handle_nc_time(ncid,n,atime)

	use nc_time

	implicit none

	integer ncid
	integer n			!time record to be requested
        double precision atime		!parsed absolute time (return)

        double precision t

	call nc_get_time_rec(ncid,n,t)

	if( time_type .eq. 1 ) then
          call handle_general_time(t,atime)
	else if( time_type .eq. 2 ) then
          call handle_warf_time(t,atime)
	else
	  write(6,*) 'time_type: ',time_type
	  stop 'error stop handle_nc_time: cannot handle'
	end if

	end

c*****************************************************************

	subroutine parse_time_units(bverb,atext,itype,date0,fact)

	implicit none

	logical bverb
	character*(*) atext
	integer itype
	integer date0
	double precision fact

	integer year,month,day

	if( atext(1:10) .eq. 'days since' ) then
	  itype = 1
	  call parse_date_time(atext(12:),year,month,day)
	  date0 = 10000*year + 100*month + day
	  fact = 86400.
	else if( atext(1:16) .eq. 'day as %Y%m%d.%f' ) then
	  itype = 2
	  date0 = 0
	  fact = 86400.
	else if( atext(1:13) .eq. 'seconds since' ) then
	  itype = 1
	  call parse_date_time(atext(15:),year,month,day)
	  date0 = 10000*year + 100*month + day
	  fact = 1.
	else if( atext(1:13) .eq. 'minutes since' ) then
	  itype = 1
	  call parse_date_time(atext(15:),year,month,day)
	  date0 = 10000*year + 100*month + day
	  fact = 60.
	else if( atext(1:11) .eq. 'hours since' ) then
	  itype = 1
	  call parse_date_time(atext(13:),year,month,day)
	  date0 = 10000*year + 100*month + day
	  fact = 3600.
	else if( atext .eq. ' ' ) then	!no time coordinate
	  itype = 0
	  date0 = 0
	  fact = 1.
	else
	  write(6,*) 'atext: ',trim(atext)
	  stop 'error stop parse_time_units: cannot parse'
	end if

	if( bverb ) then
	  write(6,*) 'parsing date0: ',trim(atext)
	  write(6,*) 'date0: ',date0
	end if

	end

c*****************************************************************

	subroutine parse_date_time(atext,year,month,day)

	implicit none

	character*(*) atext
	integer year,month,day

	read(atext(1:4),'(i4)') year
	read(atext(6:7),'(i2)') month
	read(atext(9:10),'(i2)') day

	end

c*****************************************************************

        subroutine handle_warf_time(time,atime)

	use nc_time

        implicit none

        double precision time
        double precision atime

	double precision secs
        integer date

        date = time
        secs = (time-date) * time_fact

	call dts_to_abs_time(date,0,atime)
	atime = atime + secs

	end

c*****************************************************************

        subroutine handle_general_time(time,atime)

	use nc_time

        implicit none

        double precision time
        double precision atime

	double precision secs

	secs = time * time_fact
	atime = atime0 + secs

        end

c*****************************************************************
c*****************************************************************
c*****************************************************************

        subroutine print_time_records(ncid)

c print time and date

        implicit none

        integer ncid

        integer nit,n
        double precision atime
        character*20 line

        call nc_get_time_recs(ncid,nit)
        write(6,*) 'time records found: ',nit

        do n=1,nit
          call handle_nc_time(ncid,n,atime)
          call dts_format_abs_time(atime,line)
          write(6,*) n,atime,line
        end do

        end

c*****************************************************************

        subroutine print_minmax_time_records(ncid)

c print time and date

        implicit none

        integer ncid

        integer nit
        double precision atime
        character*20 line

        call nc_get_time_recs(ncid,nit)

        if( nit == 0 ) then
          write(6,*) 'no time record found'
        else if( nit == 1 ) then
          call handle_nc_time(ncid,1,atime)
          call dts_format_abs_time(atime,line)
          write(6,*) 'one time record found: ',atime,line
        else
          write(6,*) 'time records found: ',nit
          call handle_nc_time(ncid,1,atime)
          call dts_format_abs_time(atime,line)
          write(6,*) 'first time record:  ',atime,line
          call handle_nc_time(ncid,nit,atime)
          call dts_format_abs_time(atime,line)
          write(6,*) 'last time record:   ',atime,line
        end if

        end

c*****************************************************************
c*****************************************************************
c*****************************************************************

        subroutine create_date_string(ncid,it,datetime)

        implicit none

        integer ncid,it
        integer datetime(2)

        integer ierr
        double precision atime
        character*80 line

        datetime = 0
        if( it == 0 ) return

        call handle_nc_time(ncid,it,atime)
        call dts_format_abs_time(atime,line)
        call string2datetime(line,datetime,ierr)

        if( ierr /= 0 ) then
          write(6,*) 'error converting date string: ',trim(line)
          stop 'error stop write_variables: date string'
        end if

        end

c*****************************************************************

