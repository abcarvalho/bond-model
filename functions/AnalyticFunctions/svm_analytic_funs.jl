# SVM Functions

    # ######## Pre-Volatility Shock Bond Pricing Functions #########
    # Pre-Volatility Shock Auxiliary Functions
    function rdisc_pvs(r, xi, k, _lambda)
        return r + xi * k + _lambda
    end

    function zhat_pvs(sigma, r, gross_delta, xi, k, _lambda)
        return sqrt(cvm_a(sigma, r, gross_delta)^2 * sigma^4 +
                          2 * rdisc_pvs(r, xi, k, _lambda) * sigma^2) / sigma^2
    end

    function q1_pvs(v, ttm, sigma, r, gross_delta, xi, k, _lambda)
        return (-v - zhat_pvs(sigma, r, gross_delta, xi, k, _lambda) * sigma^2 * ttm) / (sigma * sqrt(ttm))
    end

    function q2_pvs(v, ttm, sigma, r, gross_delta, xi, k, _lambda)
        return (-v + zhat_pvs(sigma, r, gross_delta, xi, k, _lambda) * sigma^2 * ttm) / (sigma * sqrt(ttm))
    end

    function G_pvs(v, ttm, sigma, r, gross_delta, xi, k, _lambda)
        return exp((- cvm_a(sigma, r, gross_delta) + zhat_pvs(sigma, r, gross_delta, xi, k, _lambda)) * v) *
                                                cdf(Normal(), q1_pvs(v, ttm, sigma, r, gross_delta, xi, k, _lambda)) +
               exp((- cvm_a(sigma, r, gross_delta) - zhat_pvs(sigma, r, gross_delta, xi, k, _lambda)) * v) *
                                                cdf(Normal(), q2_pvs(v, ttm, sigma, r, gross_delta, xi, k, _lambda))
    end

    function psi_v_td(vt, v, ttm, sigma, r, gross_delta)
        return (cdf(Normal(), (-v + vt) / (sigma * sqrt(ttm)) + cvm_a(sigma, r, gross_delta) * sigma * sqrt(ttm))
                - exp(-2 * cvm_a(sigma, r, gross_delta) * vt) *
                cdf(Normal(), (-v - vt) / (sigma * sqrt(ttm)) + cvm_a(sigma, r, gross_delta) * sigma * sqrt(ttm)))
    end

    function dv_psi_v_td(vt, v, ttm, sigma, r, gross_delta)
        return (-1./(sigma * sqrt(ttm))) *
               (pdf(Normal(), (-v + vt) / (sigma * sqrt(ttm)) + cvm_a(sigma, r, gross_delta) * sigma * sqrt(ttm))
                - exp(-2 * cvm_a(sigma, r, gross_delta) * vt) *
                pdf(Normal(), (-v - vt) / (sigma * sqrt(ttm)) + cvm_a(sigma, r, gross_delta) * sigma * sqrt(ttm)))
    end

    # Market Value of (Credit-Risk-Free) Debt at Upper Barrier:
    function rf_debt(m, c, p, r, xi, k)
        return ((c / rdisc(r, xi, k)) * (m - (1 - exp(-(rdisc(r, xi, k)) * m)) / (rdisc(r, xi, k))) +
                p * (1 - exp(-(rdisc(r, xi, k)) * m)) / (rdisc(r, xi, k)))
    end

    # Notice Psi = 1- F and does not depend on lambda
    # Prior to the volatility shock, G_pvs takes rdisc = r + xi*k + lambda!!!!
    function on_default_payoff(v, vb, ttm, m, c, p, r, xi, k, alpha)
        return (alpha * vb * exp(v) / m) * (rf_debt(m, c, p, r, xi, k) > (alpha * vb * exp(v) / m)) +
                (c / rdisc(r, xi, k) + exp(-rdisc(r, xi, k) * ttm) * (p - c / rdisc(r, xi, k))) *
                (rf_debt(m, c, p, r, xi, k) <= (alpha * vb * exp(v) / m))
    end

    function coupon_pv_fun(v, ttm, c, sigma, r, gross_delta, xi, k, _lambda)
        return (c / rdisc_pvs(r, xi, k, _lambda)) * ((1 - exp(- rdisc_pvs(r, xi, k, _lambda) * ttm) *
                                                     (1 - cvm_F(v, ttm, sigma, r, gross_delta))) -
                                                     G_pvs(v, ttm, sigma, r, gross_delta, xi, k, _lambda))
    end

    function default_payoff_pv_fun(v, vb, ttm, m, sigma, r, gross_delta, xi, k, alpha, _lambda)
        return (alpha * vb / m) * G_pvs(v, ttm, sigma, r, gross_delta, xi, k, _lambda)
    end

    function maturity_payoff_pv_fun(v, ttm, p, sigma, r, gross_delta, xi, k, _lambda)
        return p * exp(- rdisc_pvs(r, xi, k, _lambda) * ttm) * (1 - cvm_F(v, ttm, sigma, r, gross_delta))
    end

    function no_vol_shock_cf_pv(v, vb, ttm, m, c, p, sigma, r, gross_delta, xi, k, alpha, _lambda)
        return coupon_pv_fun(v, ttm, c, sigma, r, gross_delta, xi, k, _lambda) +
               default_payoff_pv_fun(v, vb, ttm, m, sigma, r, gross_delta, xi, k, alpha, _lambda) +
               maturity_payoff_pv_fun(v, ttm, p, sigma, r, gross_delta, xi, k, _lambda)
    end

    # Notice that time-to-maturity becomes ttm-u and maturity becomes ttm:
    function vol_shock_cf_integrand(vt, v_prior, v_post, vb_prior, vb_post, u, ttm, c, p,
                                   sigma_prior, sigma_post, r, gross_delta, xi, k, alpha, pi, _lambda)
        return _lambda * exp(- rdisc_pvs(r, xi, k, _lambda) * u) *
               zhi_bond_price(vb_post, v_post, ttm - u, ttm, c, p, sigma_post, r, gross_delta, xi, k, alpha, pi) *
               (-dv_psi_v_td(vt, v_prior, u, sigma_prior, r, gross_delta) / (vb_prior * exp(v_prior)))
    end

#
