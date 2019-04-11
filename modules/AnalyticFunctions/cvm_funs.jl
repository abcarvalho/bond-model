# Analytic Functions for the CVM Model

# Rates
function rgrow(r, gross_delta)
    return r - gross_delta
end

function rdisc(r, xi, k)
    return r + xi * k
end

# Auxiliary Functions
function cvm_a(sigma, r, gross_delta)
   return  (rgrow(r, gross_delta) - .5 * sigma ^ 2) / sigma ^ 2
end


function cvm_z(sigma, r, gross_delta)
    return (cvm_a(sigma, r, gross_delta)^2 * sigma^4 + 2 * r * sigma^2)^.5 / sigma^2
end


function cvm_zhat(sigma, r, gross_delta, xi, k)
    return (cvm_a(sigma, r, gross_delta)^2 * sigma^4 +
             2 * rdisc(r, xi, k) * sigma^2)^.5 / sigma^2
end


function cvm_eta(sigma, r, gross_delta)
    return cvm_z(sigma, r, gross_delta) - cvm_a(sigma, r, gross_delta)
end
  
  
# ######### Bond Price-Specific Auxiliary Functions #########
function cvm_h1(v, ttm, sigma, r, gross_delta)
    return (-v - cvm_a(sigma, r, gross_delta) * sigma^2 * ttm) / (sigma * sqrt(ttm))
end


function cvm_h2(v, ttm, sigma, r, gross_delta)
    return (-v + cvm_a(sigma, r, gross_delta) * sigma^2 * ttm) / (sigma * sqrt(ttm))
end


function cvm_q1(v, ttm, sigma, r, gross_delta, xi, k)
    return (-v - cvm_zhat(sigma, r, gross_delta, xi, k) * sigma^2 * ttm) / (sigma * sqrt(ttm))
end


function cvm_q2(v, ttm, sigma, r, gross_delta, xi, k)
    return (-v + cvm_zhat(sigma, r, gross_delta, xi, k) * sigma^2 * ttm) / (sigma * sqrt(ttm))
end
  

function cvm_F(v, ttm, sigma, r, gross_delta)
    return Distributions.cdf(Normal(), cvm_h1(v, ttm, sigma, r, gross_delta)) +
            exp(-2 * cvm_a(sigma, r, gross_delta) * v) *
           Distributions.cdf(Normal(), cvm_h2(v, ttm, sigma, r, gross_delta))
end


function cvm_G(v, ttm, sigma, r, gross_delta, xi, k)
    return exp((- cvm_a(sigma, r, gross_delta) + cvm_zhat(sigma, r, gross_delta, xi, k)) * v) *
             Distributions.cdf(Normal(), cvm_q1(v, ttm, sigma, r, gross_delta, xi, k)) +
           exp((- cvm_a(sigma, r, gross_delta) - cvm_zhat(sigma, r, gross_delta, xi, k)) * v) *
             Distributions.cdf(Normal(), cvm_q2(v, ttm, sigma, r, gross_delta, xi, k))
end
  
# Bond Price
function cvm_bond_price(vb, v, ttm, mu_b, m, c, p, sigma, r, gross_delta, xi, k, alpha, pi)
    return (c / rdisc(r, xi, k)) +
           exp(-rdisc(r, xi, k) * ttm) * (p - c / rdisc(r, xi, k)) * (1 - cvm_F(v, ttm, sigma, r, gross_delta)) +
           (alpha * vb / (mu_b * m) - c / rdisc(r, xi, k)) * cvm_G(v, ttm, sigma, r, gross_delta, xi, k)
end
  
  
# Credit-Risk-Free Bond Price
function rfbond_price(ttm, c, p, r, xi, k)
    return ((c / rdisc(r, xi, k)) +
            (p - c / rdisc(r, xi, k)) * exp(- rdisc(r, xi, k) * ttm))
end
  
  
######### vb-Specific Auxiliary Functions #########
function cvm_b(x, m, sigma, r, gross_delta, xi, k)
    return (1 / (cvm_z(sigma, r, gross_delta) + x)) *
          exp(- rdisc(r, xi, k) * m) *
          (Distributions.cdf(Normal(), x * sigma * sqrt(m)) -
           exp(r * m) * Distributions.cdf(Normal(), - cvm_z(sigma, r, gross_delta) * sigma * sqrt(m)))
end


function cvm_B(x, m, sigma, r, gross_delta)
    return (1 / (cvm_z(sigma, r, gross_delta) + x)) *
            (Distributions.cdf(Normal(), x * sigma * sqrt(m)) -
              exp(.5 * (cvm_z(sigma, r, gross_delta)^2 - x^2) * sigma^2 * m) *
              Distributions.cdf(Normal(), - cvm_z(sigma, r, gross_delta) * sigma * sqrt(m)))
end
  

function cvm_numerator1(m, c, p, sigma, r, gross_delta, xi, k, pi)
    return ((1 - pi) * (c * m) +
             (1 - exp(- rdisc(r, xi, k) * m)) *
             (p - c / rdisc(r, xi, k))) / cvm_eta(sigma, r, gross_delta)
end


function cvm_numerator2(m, c, p, sigma, r, gross_delta, xi, k)
    return (p - c / rdisc(r, xi, k)) *
            (cvm_b(- cvm_a(sigma, r, gross_delta), m, sigma, r, gross_delta, xi, k) +
              cvm_b(cvm_a(sigma, r, gross_delta), m, sigma, r, gross_delta, xi, k)) +
             (c / rdisc(r, xi, k)) *
             (cvm_B(-cvm_zhat(sigma, r, gross_delta, xi, k), m, sigma, r, gross_delta) +
              cvm_B(cvm_zhat(sigma, r, gross_delta, xi, k), m, sigma, r, gross_delta))
end


function cvm_denominator(m, sigma, r, gross_delta, iota, xi, k, alpha)
    return (gross_delta - iota) / (cvm_eta(sigma, r, gross_delta) - 1) + (alpha / m) *
            (cvm_B(- cvm_zhat(sigma, r, gross_delta, xi, k), m, sigma, r, gross_delta) +
             cvm_B(cvm_zhat(sigma, r, gross_delta, xi, k), m, sigma, r, gross_delta))
end


# Default Boundary
function cvm_vb(mu_b, m, c, p, sigma, r, gross_delta, iota, xi, k, alpha, pi)
    value = mu_b * (cvm_numerator1(m, c, p, sigma, r, gross_delta, xi, k, pi) +
                    cvm_numerator2(m, c, p, sigma, r, gross_delta, xi, k)) /
                    cvm_denominator(m, sigma, r, gross_delta, iota, xi, k, alpha)
  
    return max(convert(Float64, value), 1e-4)
end


######### Equity-Specific Auxiliary Functions #########
function cvm_gamma(sigma, r, gross_delta)
    return cvm_a(sigma, r, gross_delta) + cvm_z(sigma, r, gross_delta)
end
  

function cvm_k_fun(v, x, w, u, sigma, m)
    return exp(.5 * ((u - x)^2 - w^2) * (sigma^2) * m) *
           exp(-u * v) * Distributions.cdf(Normal(),(-v + (u - x) * (sigma^2) * m) / (sigma * sqrt(m))) -
           exp(-(x + w) * v) * Distributions.cdf(Normal(), (-v + w * (sigma^2) * m) / (sigma * sqrt(m)))
end


function cvm_K(v, x, w, u, sigma, m)
    return (Distributions.cdf(Normal(), w * sigma * sqrt(m)) -
              exp(.5 * ((u - x)^2 - w^2) * (sigma^2) * m) *
              Distributions.cdf(Normal(),(u - x) * sigma * sqrt(m))) * exp(- u * v) +
             cvm_k_fun(v, x, w, u, sigma, m)
end

  
function cvm_A(v, y, sigma, r, gross_delta, m)
    return 1 / (cvm_z(sigma, r, gross_delta) - y) *
        (cvm_K(v, cvm_a(sigma, r, gross_delta), y, cvm_gamma(sigma, r, gross_delta), sigma, m) +
         cvm_k_fun(v, cvm_a(sigma, r, gross_delta), - y, - cvm_eta(sigma, r, gross_delta), sigma, m)) +
        1 / (cvm_z(sigma, r, gross_delta) + y) *
        (cvm_K(v, cvm_a(sigma, r, gross_delta), - y, cvm_gamma(sigma, r, gross_delta), sigma, m) +
         cvm_k_fun(v,cvm_a(sigma, r, gross_delta), y, - cvm_eta(sigma, r, gross_delta), sigma, m))
end


# Equity Value
function cvm_eq(v, mu_b, m, c, p, sigma, r, gross_delta, iota, xi, k, alpha, pi)
    vbl = cvm_vb(mu_b, m, c, p, sigma, r, gross_delta, iota, xi, k, alpha, pi)
    net_delta = (gross_delta - iota)

    cf1 = 1 / (r - rgrow(r, gross_delta))
    cf20 = 1 / (sigma^2 * cvm_z(sigma, r, gross_delta))
    cf21 = 1 / (cvm_gamma(sigma, r, gross_delta) + 1) 
    cf2 = - cf20 * cf21
    cf30 = (1 - pi) * (c * m)
    cf31 = (1 - exp(- rdisc(r, xi, k) * m))
    cf32 = (p - c / rdisc(r, xi, k))
    cf3 = - (cf30 +  cf31 * cf32) * cf20
    cf4 = 1 / cvm_eta(sigma, r, gross_delta)
    cf5 = 1 / cvm_gamma(sigma, r, gross_delta)
    cf6 = cf20
    cf7 = exp(- rdisc(r, xi, k) * m) * cf32
    cf8 = alpha/m
    cf9 = - c / rdisc(r, xi, k)
    
    vf1 = exp(v)
    vf2 = exp(-cvm_gamma(sigma, r, gross_delta) * v)
    vf3 = (1 - exp(- cvm_gamma(sigma, r, gross_delta) * v))
    vf4 = cvm_A(v, cvm_a(sigma, r, gross_delta), sigma, r, gross_delta, m) 
    vf5 = cvm_A(v, cvm_zhat(sigma, r, gross_delta, xi, k), sigma, r, gross_delta, m)
    
    return  mu_b * (net_delta * (vbl/mu_b) * (cf1 * vf1 +  cf2 * vf2) +
                    cf3 * (cf4 + cf5 * vf3) +
                    cf6 * (cf7 * vf4 - (cf8 * (vbl/mu_b) + cf9) * vf5))
end

    # cf2 = - (net_delta / (sigma^2 * cvm_z(sigma, r, gross_delta) * (cvm_gamma(sigma, r, gross_delta) + 1)))
    # cf3 = - mu_b * (((1 - pi) * (c * m) + (1 - exp(- rdisc(r, xi, k) * m)) *
    #                  (p - c / rdisc(r, xi, k))) / (sigma^2 * cvm_z(sigma, r, gross_delta)))
    # cf4 = (mu_b / (cvm_z(sigma, r, gross_delta) * sigma^2))
    # cf5 = exp(- rdisc(r, xi, k) * m) * (p - c / rdisc(r, xi, k))
    # cf6 = (alpha * vb / (mu_b * m) - c / rdisc(r, xi, k)) 

    # return cf1 * vb * exp(v) + cf2 * vb * exp(-cvm_gamma(sigma, r, gross_delta) * v) +
    #        cf3 * (1 / cvm_eta(sigma, r, gross_delta) +
    #               (1 - exp(- cvm_gamma(sigma, r, gross_delta) * v)) / cvm_gamma(sigma, r, gross_delta)) +
    #        cf4 * (cf5 * cvm_A(v, cvm_a(sigma, r, gross_delta), sigma, r, gross_delta, m) +
    #               cf6 * cvm_A(v, cvm_zhat(sigma, r, gross_delta, xi, k), sigma, r, gross_delta, m))

