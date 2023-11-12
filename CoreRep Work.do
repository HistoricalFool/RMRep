/*********************************
* Tate Mason                     *
* UNC Charlotte                  *
* Figuring out what Gaggl did.do *
*********************************/

/********************************
* 1. Environment Setup          *
********************************/
	#delimit cr 		
	clear				
	clear all			
	set more off	
	
	set scheme black_tableau
	
	//Data Paths
	
	local data "/Users/tate/Dropbox/Schoolwork/RM/Data"
	local output "/Users/tate/Dropbox/Schoolwork/RM/Output"
	
	local prepRaw = 0
	local prepDummies = 0
	local doGraph = 0
	
/********************************
* 2. Data Setup                 *
********************************/
	if `prepRaw' {
			
			use `data'/IPUMS-USA_CoreRep.dta, clear
			
			keep if inlist(year,1960,1970,1980,1990,2000,2010,2019)
			
			
		
			gen rent_inc = 100*rentgrs/(inctot/12) if inctot>0
			gen hval_inc = valueh/(inctot/12) if inctot>0
			
			
			gen inc_month = inctot/12
			gen own100 = 100*(1-renter)
			
			//compute percentiles
			local vars "rentgrs valueh own100 inc_month"
			
			levelsof year, local(years)
			
			foreach v of local vars {
				di "computing percentiles for `v'..."
				gen pctr_`v'=.
				foreach y of local years {
					di "    year=`y'..."
					xtile pctr_`v'_`y' = `v' [aw=hhwt] if year==`y', nq(100)
					replace pctr_`v'=pctr_`v'_`y' if year==`y'
				}
				
				
			}
			
		
			
			save "`data'/fig2data.dta", replace
		
		}
		
/********************************
* 3. Prep Dummies               *
********************************/		
		
if `prepDummies' {
		
		use "`data'/fig2data.dta", clear
		
		
		
			levelsof pctr_inc_month, local(ps)
			foreach p of local ps {
				 
				di "p=`p'"
				
				//generate dummy for income ranks
					gen _incr_p`p' = 0 if pctr_inc_month!=.
					replace _incr_p`p' = 1 if pctr_inc_month==`p'
					
				//generate interaction with black
					gen _ia_black_incr_p`p' = black*_incr_p`p'
				
				
			}
			
			
			save "`data'/fig2_reg_data.dta", replace
			
		}

/********************************
* 4. Gap Regressions            *
********************************/

		use `data'/fig2_reg_data.dta

		//create interactions
			gen _ia_black_y = black*pctr_inc_month
		
		//run regression for each year and outcome
			
			
			local vars "rentgrs valueh own100"
			local controls "educ age sex hhtype farm metarea statefip"
			local years "1960,1970,1980,1990,2000,2010,2019"
			
			sum `controls'
		
			replace pctr_own100=own100 //this one is a linear probability model (no rank necessary)
			levelsof year, local(years) //grab available years
			foreach v of local vars {
				gen rgap_`v'_p25=.
				gen rgap_`v'_p50=.
				gen rgap_`v'_p75=.
				foreach y of local years {
			
					//run parametric regression (linear in income rank)
						reg pctr_`v' pctr_inc_month black _ia_black_y `controls' [aw=hhwt] if year==`y', 
					
					//predice black gap at various income ranks
						replace rgap_`v'_p25 = _b[black] + _b[_ia_black_y]*25 if year==`y'
						replace rgap_`v'_p50 = _b[black] + _b[_ia_black_y]*50 if year==`y'
						replace rgap_`v'_p75 = _b[black] + _b[_ia_black_y]*75 if year==`y'
				}
				
			}
			
/********************************
* 5. Graphing                   *
********************************/	
if `doGraph' {
		preserve
			//collapse saved coefficients by year
				collapse rgap*, by(year)
		
			//plot saved coefficients
				tsset year
			
			
				graph drop _all
		
				local vars "rentgrs valueh own100"
				foreach v of local vars {
				
					if "`v'"=="rentgrs" {
						local ylab "Black/White Rent Rank Gap"
					}
					else if "`v'"=="valueh" {
						local ylab "Black/White House Price Rank Gap"
					}
					else if "`v'"=="own100" {
						local ylab "Black/White Ownership Gap (perc. pt.)"
					}
				
				#delimit ;
					tsline rgap_`v'_p25 rgap_`v'_p50 rgap_`v'_p75,
				
					lwidth(thin thick thin)
					lpattern(dash solid solid)
				
					legend(ring(0) pos(5) col(1) region(style(none)) order(1 "25-th Perc. Inc. Rank" 2 "50-th Perc. Inc. Rank" 3 "75-th Perc. Inc. Rank"))
				
					xlabel(1940(10)2020, grid gstyle(major) glstyle(dot) glcolor(black) glwidth(small))
					ylabel(-20(5)0, grid gstyle(major) glstyle(dot) glcolor(black) glwidth(small))
					yline(0,lcolor(black) lwidth(thin))
				
					ytitle("`ylab'")
					xtitle("Year")
				
				
					name(`v')
				
					;
				#delimit cr
					graph export "`output'/rgap_`v'.pdf", as(pdf) name(`v') replace
				}
			restore	
			}
			
/********************************
* Direct Quality Obs.           *
********************************/
		//bedrooms and whatever
		local controls "educ age sex hhtype farm metarea statefip"
			by year: reg bedrooms black `controls'
			by year: reg builtyr black `controls'
