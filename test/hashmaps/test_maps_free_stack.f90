program test_maps_free_stack
!! Regression test: freeing a large hash map must not use stack space that
!! grows with the number of entries.
!!
!! Map entries are allocated in pools of 64. Freeing a map used to recurse
!! once per pool, so a map with 2**20 entries (16384 pools) needed at least
!! 256 KiB of stack just to be freed. On Unix-like systems CMake runs this
!! test under a 128 KiB stack limit, so a recursive free crashes it.

    use stdlib_kinds, only: int32
    use stdlib_hashmaps, only: chaining_hashmap_type, open_hashmap_type

    implicit none

    integer(int32), parameter :: n_entries = 2**20

    call fill_and_free_chaining_map()
    call fill_and_free_open_map()

    print '(a, i0, a)', 'Freed chaining and open maps of ', n_entries, &
        ' entries each.'

contains

    subroutine fill_and_free_chaining_map()
        type(chaining_hashmap_type) :: map
        integer(int32) :: i

        call map % init( slots_bits=20 )
        do i = 1, n_entries
            call map % map_entry( [i] )
        end do
        if ( map % entries() /= n_entries ) &
            error stop 'chaining map: unexpected number of entries'
!       map is finalized on return, which frees all of its entry pools
    end subroutine fill_and_free_chaining_map

    subroutine fill_and_free_open_map()
        type(open_hashmap_type) :: map
        integer(int32) :: i

        call map % init( slots_bits=21 )
        do i = 1, n_entries
            call map % map_entry( [i] )
        end do
        if ( map % entries() /= n_entries ) &
            error stop 'open map: unexpected number of entries'
!       map is finalized on return, which frees all of its entry pools
    end subroutine fill_and_free_open_map

end program test_maps_free_stack
