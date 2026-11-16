module {
	
	dep.func @ZeroExtend(%out_width : i64, %value : !dep.bitvector<"N">, %N : i64)
		->!dep.bitvector<"out_width">
		binds {
			%out_width -> "out_width",
			%N -> "N"
		}
		requires {
		^bb0(%arg0 : i64, %arg1 : i64):
			%assert = arith.cmpi uge, %arg0, %arg1 : i64
			dep.yield %assert : i1
		}
	{
		%ret = "dep.bitvector.zext"(%value, %out_width) :
			(!dep.bitvector<"N">, i64) -> (!dep.bitvector<"out_width">)
		dep.yield %ret : !dep.bitvector<"out_width">
	}

	dep.func @Replicate(%out_width : i64, %value : !dep.bitvector<"N">, %N : i64)
		-> !dep.bitvector<"out_width">
		binds {
			%out_width -> "out_width",
			%N -> "N"
		}
		requires {
		^bb0(%arg0 : i64, %arg1 : i64):
			// we must check that N divides out_width
			//%q = arith.divsi %arg0, %arg1 : i64
			//%product = arith.muli %q, %arg1 : i64
			//%diff = arith.subi %arg1, %product : i64
			//%zero = arith.constant 0 : i64
			//%assert = arith.cmpi ne, %diff, %zero : i64
			%assert = arith.constant 1 : i1

			dep.yield %assert : i1
		}
	{
		%zero_vec = "dep.bitvector.zeros"(%out_width) : (i64) -> (!dep.bitvector<"out_width">)

		%c_zero = arith.constant 0 : index
		%c_one = arith.constant 1 : index
		%q64 = arith.divsi %out_width, %N : i64
		%q = arith.index_cast %q64 : i64 to index
		%out_vector = scf.for %i = %c_zero to %q step %c_one iter_args(%arg0 = %zero_vec) -> (!dep.bitvector<"out_width">)
		{
			%arg0_shifted = "dep.bitvector.shl"(%arg0, %N) :
				(!dep.bitvector<"out_width">, i64) -> (!dep.bitvector<"out_width">)
			%next = "dep.bitvector.or"(%arg0, %arg0_shifted) :
				(!dep.bitvector<"out_width">, !dep.bitvector<"out_width">) -> (!dep.bitvector<"out_width">)

			scf.yield %next : !dep.bitvector<"out_width">
		}

		dep.yield %out_vector : !dep.bitvector<"out_width">
	}

	dep.func @RotateRight(%M : i64, %data : !dep.bitvector<"M">, %amount : i64)
		-> !dep.bitvector<"M">
		binds {
			%M -> "M"
		}
	{
		%result = "dep.bitvector.ror"(%data, %amount) : (!dep.bitvector<"M">, i64) -> (!dep.bitvector<"M">)
		dep.yield %result : !dep.bitvector<"M">
	}

	dep.func @HighestSetBitNotZero(%M : i64, %value : !dep.bitvector<"M">) -> i64
		binds {
			%M -> "M"
		}
	{
		%zero = arith.constant 0 : i64

		%highest_bit =
		scf.while (%arg0 = %value, %arg1 = %zero) : (!dep.bitvector<"M">, i64) -> i64 
		{
			%condition = "deps.bitvector.empty"(%value): !dep.bitvector<"M"> -> i1
		}
	}

	dep.func @DecodeBitMasks(%M : i64, %immN : i1, %imms : i6, %immr : i6, %immediate : i1)
		-> (!dep.bitvector<"M">, !dep.bitvector<"M">)
		binds {
			%M -> "M"
		}
	{
		// var levels : bits(6);

		// // Compute log2 of element size
		// // 2^len must be in range [2, M]
		// if immN::NOT(imms) == '000000x' then Undefined(); end;
		%neg_mask = arith.constant 0x3f : i6
		%imms_neg = arith.xori %imms, %neg_mask : i6
		%imms_neg7 = arith.extui %imms_neg7 : i6 to i7
		%immN_ext = arith.extui %immN : i1 to i7
		%c_six = arith.constant 6 : i64
		%immN_shifted = arith.shl %immN_ext, %c_six : i7
		%immN_concat_not_imms = arith.or %imms_neg7, %immN_shifted : i7

		%c_one7 = arith.constant 1 : i7
		%condition = arith.cmpi gt, %immN_concat_not_imms, %c_one7 : i7
		cf.assert %condition, "if immN::NOT(imms) == '000000x' then Undefined()"

		// let len : integer{} = HighestSetBitNZ(immN::NOT(imms));
		%len = dep.call @HighestSetBitNotZero() // FINISH!!!


		// assert 2 <= (2^len) && (2^len) <= M;
		%one_const = arith.constant 1 : i6
		%len_exp = arith.shli %one_const, %len : i6
		%two_const = arith.constant 2 : i6
		%cnd1_lhs = arith.cmpi ule, %two_const, %len_exp : i6
		%cnd1_rhs = arith.cmpi ule, %len_exp, %M : i6
		%cnd1 = arith.andi %cnd1_lhs, %cnd1_rhs : i1
		cf.assert %cnd1, "assert 2 <= (2^len) && (2^len) <= M"

		// // Determine s, r and s - r parameters

		// levels = ZeroExtend{6}(Ones{len});
		%levels = arith.subi %len_exp, %one_const : i6

		// // For logical immediates an all-ones value of s is reserved
		// // since it would generate a useless all-ones result (many times)
		// if immediate && (imms AND levels) == levels then Undefined(); end;
		%imms_and_levels = arith.andi %imms, %levels : i6
		%cnd2_rhs = arith.cmp eq, %imms_and_levels, %levels : i6
		%cnd2 = arith.andi %immediate, %cnd2_rhs : i1
		%cnd2_inv = arith.xori %cnd2, %one_const : i1
		cf.assert %cnd2, "if immediate && (imms AND levels) == levels then Undefined()"

		// let s : integer{} = UInt(imms AND levels);
		%s = arith.extui %imms_and_levels : i6 to i64

		// let r : integer{} = UInt(immr AND levels);
		%immr_and_levels = arith.andi %immr, %levels : i6
		%r = arith.extui %immr_and_levels : i6 to i64

		// let diff : integer{} = s - r;    // 6-bit subtract with borrow
		%diff = arith.subi %s, %r : i64

		// let esize : integer{} = 1 << len;
		%one_const64 = arith.constant 1 : i64
		%len_int = arith.extui %len : i6 to i64
		%esize = arith.shli %one_const64, %len : i64

		// let d : integer{}     = UInt(diff[len-1:0]);
		%64_const = arith.constant 64 : i64
		%shift_amount = arith.subi %64_const, %len : i64
		%shifted_d = arith.shli %diff, %shift_amount : i64
		%d = arith.shrui %shifted_d, %shift_amount : i64

		// let welem : bits(esize) = ZeroExtend{}(Ones{s + 1});
		%c_one = arith.constant 1 : i64
		%s_plus_one = arith.addi %s, %c_one : i64
		%s_ones_vec = dep.bitvector.ones %s_plus_one : !dep.bitvector<"s_plus_one">
		%welem = dep.bitvector.zext %s_ones_vec, %esize : !dep.bitvector<"esize">

		// let telem : bits(esize) = ZeroExtend{}(Ones{d + 1});
		%d_plus_one = arith.addi %s, %c_one : i64
		%d_ones_vec = dep.bitvector.ones %d_plus_one : !dep.bitvector<"d_plus_one">
		%telem = dep.bitvector.zext %ones_vec, %esize : !dep.bitvector<"esize">

		// let wmask : bits(M) = Replicate{}(ROR(welem, r));
		%rotated_welem = dep.call @RotateRight(%M, %welem, %r) : !dep.bitvector<"M">


		// let tmask : bits(M) = Replicate{}(telem);
		%tmask = dep.call %Replicate(%M, %telem) : !dep.bitvector<"M">

		// return (wmask, tmask);
	}

	
}
