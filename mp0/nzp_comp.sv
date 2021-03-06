module nzp_comp (
	input n,inst_n, z, inst_z, p, inst_p,
	output logic br_en
);

	always_comb
	begin
		if ((n && inst_n) || (z && inst_z) || (p && inst_p))
			br_en = 1;
		else
			br_en = 0;
	end
endmodule : nzp_comp
