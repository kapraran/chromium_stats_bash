#!/bin/bash
# Νικόλαος Καπράρας, ΑΕΜ 2166, kapraran@csd.auth.gr

# --------------------------------------------------------------------
# Ι. Ορισμός βασικών συναρτήσεων
# --------------------------------------------------------------------

# (1) Προετοιμασία εκτέλεσης
INITIALIZE() {
    # Διαβάζει τη λίστα των διεργασιών του chromium
    local pids=$(get_chromium_pids)
    
    # Τερματίζει τις υπάρχουσες διεργασίες του chromium
    for pid in $pids; do
        kill -9 $pid > /dev/null 2>&1
    done

    # Διαγράφει τον φάκελο με τα αποτελέσματα της προηγούμενης εκτέλεσης
    # και ετοιμάζει τα αρχεία/φακέλους που απαιτούνται για την επόμενη
    rm -rf result > /dev/null 2>&1
    mkdir result > /dev/null 2>&1
    touch result/data.out
}

# (2) Διαχείριση διεργασιών
CREATE_AND_TERMINATE_PROCESSES() {
    # Εκκινεί τον chromium
    chromium_start

    # Διαβάζει κάθε url απο το url.in και ανοίγει νέο tab για το 
    # καθένα από αυτά ανα 5 δευτερόλεπτα
    while read url; do
    	echo "Άνοιγμα:" $url
        chromium_start $url
        sleep 5
    done < 'url.in'

    echo "Resting..."
    sleep 30

    echo "Τερματισμός διεργασιών"
    # Διαβάζει τη λίστα των chromium_pids ταξινομημένες με βάση 
    # τον χρόνο εκτέλεσης τους
    local pids=$(get_chromium_pids)

    # Τερματίζει μια-μια τις υπάρχουσες διεργασίες του chromium-browser,
    # ανα 5 δευτερόλεπτα
    for pid in $pids; do
        kill -9 $pid > /dev/null 2>&1
        sleep 5
    done

    # !Σημείωση
    # ---------
    # Ο παρακάτω τρόπος συμβαδίζει περισσότερο με την εκφώνηση αλλά συνεχώς κατέληγα σε
    # endless loop γιατί κάποιες διεργασίες δεν τερματίζονταν ποτέ.
    # 
    # # Ελέγχει αν υπάρχουν διεργασίες του chromium
    # while [ $(get_chromium_pids_number) -gt 0 ]; do
    #     # Διαβάζει τη λίστα των διεργασιών του chromium και 
    #     # επιλέγει την νεότερη (πρώτη στη λίστα)
    #     local pids=$(get_chromium_pids)
    #     local latest_pid=$(echo $pids | tr ' ' '\n' | head -n 1)
    #
    #     # Τερματίζει την διεργασία
    #     kill -9 $latest_pid
    #     sleep 5
    # done
}

# (3) Καταγραφή στατιστικών στοιχείων
GATHER_STATISTICS() {
    local secs=0

    # Ελέγχει αν υπάρχουν διεργασίες του chromium και μαζεύει μια
    # σειρά απο στατιστικά στο data.out, ανα 0.5 δευτερόλεπτα
    while [ $(get_chromium_pids_number) -gt 0 ]; do
        # Μαζεύει τα στατιστικά που μας ενδιαφέρουν, για τη συγκεκριμένη χρονική στιγμή
        gather_current_stats $secs # βολεύει να το βάλω να τρέχει και στο background ώστε οι χρόνοι να ειναι πιο κοντα στην πραγματικότητα
        sleep 0.5
        secs=$(echo "$secs + 0.5" | bc -l)
    done
}

# (4) Δημιουργία γραφικών παραστάσεων
CREATE_PLOTS() {
    mkdir result/plots
    gnuplot 'plots_script.gp'
}

# --------------------------------------------------------------------
# ΙΙ. Ορισμός βοηθητικών συναρτήσεων
# --------------------------------------------------------------------

# Εμφανίζει μια λίστα με όλα τα pids των διεργασιών του chromium, 
# ταξινομημένα με βάση των χρόνο εκτέλεσης τους (etime)
get_chromium_pids() {
    ps -C chromium-browser --sort=etime | awk '/chromium/ {print $1}' | tr '\n' ' '
}

# Εκκινεί τον chromium
#
# $1 Το url της σελίδας που επιθυμούμε να ανοίξει ο chromium (προεραιτικό)
chromium_start() {
    if [ -n "$1" ]; then
        chromium-browser $1 > /dev/null 2>&1 &
    else
        chromium-browser > /dev/null 2>&1 &
    fi
}

# Εμφανίζει τον αριθμό των pids, που σχετίζονται με τον chromium
get_chromium_pids_number() {
    get_chromium_pids | tr ' ' '\n' | grep -c .
}

# Συλλέγει τα στατιστικά για το chromium που μας ενδιαφέρουν, για μια συγκεκριμένη
# χρονική στιγμή και τα αποθηκεύει στο αρχείο data.out
gather_current_stats() {
    # Διαβάζει τη λίστα των διεργασιών του chromium
    local pids=$(get_chromium_pids)
    # Βρίσκει τον συνολικό αριθμό των διεργασιών του chromium
    local total_procs=$(echo $pids | tr ' ' '\n' | grep -c .)

    # Αρχικοποιεί κάποιες μεταβλητές που χρειάζονται στην καταγραφή των στατιστικών
    local threads_tmp=0
    local threads_sum=0
    local threads_max=0
    local threads_ave=0

    local rss_tmp=0
    local rss_sum=0
    local rss_max=0

    local vcs_tmp=0
    local vcs_sum=0
    local vcs_ave=0

    local nvcs_tmp=0
    local nvcs_sum=0
    local nvcs_ave=0

    for pid in $pids; do
        rss_tmp=$(get_proc_rss $pid) # rss της διεργασίας
        threads_tmp=$(get_proc_stat $pid Threads) # αριθμός thread της διεργασίας
        vcs_tmp=$(get_proc_stat $pid voluntary_ctxt_switches) # αριθμός voluntary_ctxt_switches της διεργασίας
        nvcs_tmp=$(get_proc_stat $pid nonvoluntary_ctxt_switches) # αριθμός nonvoluntary_ctxt_switches της διεργασίας

        # Ελέγχουμε την περιπτωση που η διεργασία έχει τερματιστεί
        # απο την CREATE_AND_TERMINATE_PROCESSES που τρέχει παράλληλα
        # οπότε και μειώνουμε τον μετρητή των διεργασιών και προχωράμε στο
        # επόμενο $pid
        if [ -z $nvcs_tmp ]; then
            total_procs=$(($total_procs - 1))
            continue
        fi

        threads_sum=$(($threads_sum + $threads_tmp)) # σύνολο threads
        vcs_sum=$(($vcs_sum + $vcs_tmp)) # σύνολο voluntary_ctxt_switches
        nvcs_sum=$(($nvcs_sum + $nvcs_tmp)) # σύνολο nonvoluntary_ctxt_switches
        rss_sum=$(($rss_sum + $rss_tmp)) # σύνολο rss

        # Εύρεση μέγιστου αριθμού threads ανα διεργασία
        if [ "$threads_tmp" -gt "$threads_max" ]; then
            threads_max=$threads_tmp
        fi

        # Εύρεση μέγιστου αριθμού rss ανα διεργασία
        if [ "$rss_tmp" -gt "$rss_max" ]; then
            rss_max=$rss_tmp
        fi
    done

    # Ελέγχει την ύπαρξη διεργασιών, καθώς υπάρχει περίπτωση να έχουν τερματιστεί όλες 
    # κατα την διάρκεια του loop. Αν υπάρχουν διεργασίες, καταγράφει τα στατιστικά
    if [ "$total_procs" -gt 0 ]; then
        threads_ave=$(echo "scale=2; $threads_sum / $total_procs" | bc -l) # μέσος όρος threads
        vcs_ave=$(echo "scale=2; $vcs_sum / $total_procs" | bc -l) # μέσος όρος voluntary_ctxt_switches
        nvcs_ave=$(echo "scale=2; $nvcs_sum / $total_procs" | bc -l) # μέσος όρος nonvoluntary_ctxt_switches

        echo $1 $total_procs $threads_max $threads_ave $(kb_to_mb $rss_sum) $(kb_to_mb $rss_max) $vcs_ave $nvcs_ave >> result/data.out
    fi
}

# Εμφανίζει την τιμή ενός στατιστικού που επιθυμούμε απο μια συγκεκριμένη διεργασία,
# διαβάζοντας το μέσα απο το αντίστοιχο proc/$pid/status αρχείο
#
# $1 To pid της διεργασίας
# $2 Το όνομα του στατιστικού που επιθυμούμε
get_proc_stat() {
    cat /proc/$1/status 2> /dev/null | grep \^$2\: | awk -F: '{print $2}'
}

# Εμφανίζει την τιμή του RSS, μιας συγκεκριμένης διεργασίας
#
# $1 To pid της διεργασίας
get_proc_rss() {
    ps p $1 -o pid,rss | tail -n 1 | awk '{print $2}'
}

# Μετατρέπει kb σε mb
#
# $1 Ο αριθμός των kb προς μετατροπή
kb_to_mb() {
	echo "scale=2; $1 / 1024" | bc -l
}

# --------------------------------------------------------------------
# ΙΙΙ. Εκτέλεση του script
# --------------------------------------------------------------------

echo "Έναρξη script"
INITIALIZE

echo "Διαχείριση διεργασιών και καταγραφή στατιστικών..."
CREATE_AND_TERMINATE_PROCESSES &
GATHER_STATISTICS &

# Περιμένει να τελειώσουν τα background jobs
wait > /dev/null 2>&1

echo "Δημιουργία γραφικών παραστάσεων"
CREATE_PLOTS

echo "Τέλος script"