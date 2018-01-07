# Combine version map fragments into version scripts for our shared objects.
# Copyright (C) 1998-2017 Free Software Foundation, Inc.
# Written by Ulrich Drepper <drepper@cygnus.com>, 1998.

# This script expects the following variables to be defined:
# defsfile		name of Versions.def file
# buildroot		name of build directory with trailing slash
# move_if_change	move-if-change command

# Read definitions for the versions.
BEGIN {
  lossage = 0;

  nlibs=0;
  while (getline < defsfile) {
    if (/^[a-zA-Z0-9_.]+ \{/) {
      libs[$1] = 1;
      curlib = $1;
      while (getline < defsfile && ! /^}/) {
	if ($2 == "=") {
	  renamed[curlib "::" $1] = $3;
	}
	else
	  versions[curlib "::" $1] = 1;
      }
    }
  }
  close(defsfile);

  tmpfile = buildroot "Versions.tmp";
  # POSIX sort needed.
  sort = "sort -t. -k 1,1 -k 2n,2n -k 3 > " tmpfile;
}

# Remove comment lines.
/^ *#/ {
  next;
}

# This matches the beginning of the version information for a new library.
/^[a-zA-Z0-9_.]+/ {
  actlib = $1;
  if (!libs[$1]) {
    printf("no versions defined for %s\n", $1) > "/dev/stderr";
    ++lossage;
  }
  next;
}

# This matches the beginning of a new version for the current library.
/^  [A-Za-z_]/ {
  if (renamed[actlib "::" $1])
    actver = renamed[actlib "::" $1];
  else if (!versions[actlib "::" $1] && $1 != "GLIBC_PRIVATE") {
    printf("version %s not defined for %s\n", $1, actlib) > "/dev/stderr";
    ++lossage;
  }
  else
    actver = $1;
  next;
}

# This matches lines with names to be added to the current version in the
# current library.  This is the only place where we print something to
# the intermediate file.
/^   / {
  sortver=actver
  # Ensure GLIBC_ versions come always first
  sub(/^GLIBC_/," GLIBC_",sortver)
  printf("%s %s %s\n", actlib, sortver, $0) | sort;
}


function closeversion(name, oldname) {
  if (firstinfile) {
    printf("  local:\n    *;\n") > outfile;
    firstinfile = 0;
  }
  # This version inherits from the last one only if they
  # have the same nonnumeric prefix, i.e. GLIBC_x.y and GLIBC_x.z
  # or FOO_x and FOO_y but not GLIBC_x and FOO_y.
  pfx = oldname;
  sub(/[0-9.]+/,".+",pfx);
  if (oldname == "" || name !~ pfx) print "};" > outfile;
  else printf("} %s;\n", oldname) > outfile;
}

function close_and_move(name, real_name) {
  close(name);
  system(move_if_change " " name " " real_name " >&2");
}

# Now print the accumulated information.
END {
  close(sort);

  if (lossage) {
    system("rm -f " tmpfile);
    exit 1;
  }

  oldlib = "";
  oldver = "";
  real_first_ver_header = buildroot "first-versions.h"
  first_ver_header = real_first_ver_header "T"
  printf("#ifndef _FIRST_VERSIONS_H\n") > first_ver_header;
  printf("#define _FIRST_VERSIONS_H\n") > first_ver_header;
  real_ldbl_compat_header = buildroot "ldbl-compat-choose.h"
  ldbl_compat_header = real_ldbl_compat_header "T"
  printf("#ifndef _LDBL_COMPAT_CHOOSE_H\n") > ldbl_compat_header;
  printf("#define _LDBL_COMPAT_CHOOSE_H\n") > ldbl_compat_header;
  printf("#ifndef LONG_DOUBLE_COMPAT\n") > ldbl_compat_header;
  printf("# error LONG_DOUBLE_COMPAT not defined\n") > ldbl_compat_header;
  printf("#endif\n") > ldbl_compat_header;
  printf("version-maps =");
  while (getline < tmpfile) {
    if ($1 != oldlib) {
      if (oldlib != "") {
	closeversion(oldver, veryoldver);
	oldver = "";
	close_and_move(outfile, real_outfile);
      }
      oldlib = $1;
      real_outfile = buildroot oldlib ".map";
      outfile = real_outfile "T";
      firstinfile = 1;
      veryoldver = "";
      printf(" %s.map", oldlib);
    }
    if ($2 != oldver) {
      if (oldver != "") {
	closeversion(oldver, veryoldver);
	veryoldver = oldver;
      }
      printf("%s {\n  global:\n", $2) > outfile;
      oldver = $2;
    }
    printf("   ") > outfile;
    for (n = 3; n <= NF; ++n) {
      printf(" %s", $n) > outfile;
      sym = $n;
      sub(";", "", sym);
      first_ver_macro = "FIRST_VERSION_" oldlib "_" sym;
      if (!(first_ver_macro in first_ver_seen) \
	  && oldver ~ "^GLIBC_[0-9]" \
	  && sym ~ "^[A-Za-z0-9_]*$") {
	ver_val = oldver;
	gsub("\\.", "_", ver_val);
	printf("#define %s %s\n", first_ver_macro, ver_val) > first_ver_header;
	first_ver_seen[first_ver_macro] = 1;
	if (oldlib == "libc" || oldlib == "libm") {
	  printf("#if LONG_DOUBLE_COMPAT (%s, %s)\n",
		 oldlib, ver_val) > ldbl_compat_header;
	  printf("# define LONG_DOUBLE_COMPAT_CHOOSE_%s_%s(a, b) a\n",
		 oldlib, sym) > ldbl_compat_header;
	  printf("#else\n") > ldbl_compat_header;
	  printf("# define LONG_DOUBLE_COMPAT_CHOOSE_%s_%s(a, b) b\n",
		 oldlib, sym) > ldbl_compat_header;
	  printf("#endif\n") > ldbl_compat_header;
	}
      }
    }
    printf("\n") > outfile;
  }
  printf("\n");
  printf("#endif /* first-versions.h */\n") > first_ver_header;
  printf("#endif /* ldbl-compat-choose.h */\n") > ldbl_compat_header;
  closeversion(oldver, veryoldver);
  close_and_move(outfile, real_outfile);
  close_and_move(first_ver_header, real_first_ver_header);
  close_and_move(ldbl_compat_header, real_ldbl_compat_header);
  #system("rm -f " tmpfile);
}
