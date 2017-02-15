namespace eval ::chip_planner::dcg:: {
    proc pr_ports {} {
        make_rdb_table "ports||oports" #f0f [gui_find -atoms "*~oport"] -min_size 8
        make_rdb_table "ports||iports" #0f0 [gui_find -atoms "*~iport"] -min_size 8
    }
}

