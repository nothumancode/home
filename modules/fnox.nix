{ ... }:
{
  programs.fnox = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;
    settings = {
      default_provider = "age";
      daemon.enabled = true;
      providers.age = {
        type = "age";
        recipients = [ "age18htgmznct68n7mw2gjakf4udpg97cs7vdvkddulsgu485y0vspxqe5ln4a" ];
      };
      providers.doppler = {
        type = "doppler";
        project = "vault";
        config = "prd";
        token = {
          secret = "DOPPLER_TOKEN";
        };
      };
      secrets = {
        GHE_NPM_TOKEN = {
          provider = "age";
          value = "YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBjeWZVUmJ5ZW1zSW1BR1U3VGIrT0QxUlNBZW84L2hsYVRZWnR6RC92SlRJCmFabkV3Y1hvemN3Q1IrMjdZWjhZa3huNFVFbXVINVNwMkMzb0pzZFoyZnMKLT4gd1EjJC1ncmVhc2UgM0BsLWBvXD8gOnMgMQpWVFRRMFpyRnE1cnh1aXNva1pLVDNZVnlGOFV2ek5Kek5FaDdSc25rUG9BLzJtclRZcTN5K00rQWkwTzdqUUZVCklRTU8KLS0tIDd5M2RBNk9ORmI0K1d2NjljZlJCSUxwd2JiMnBBK3h3TGdqbUhCYU9ZUUEKBW+7qyd1TdBwC+dudI6qdmDbCVG9FGNsCPvTHzE1e9mUmmZRSRdfaJ8XPA3QjpJyZ7qQHpmdFgQcQknK17Hz+n4cQC9KhlhO";
        };
        AI_GATEWAY_API_KEY = {
          provider = "age";
          value = "YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBNUmpObkVDbDRpSHZscnlZVmpIMkVDNmszZEdtdkU4elJIc2tyVVJJYVRZCkpxVEJSY1N6WjQrbC9sL05nVzZ3cmZBR1J2Z2QvdmNQMnlFaEZHRFBXdUEKLT4gOEktZ3JlYXNlIFJmZFBnIFtePFVRJ3EgbCJ7Rz08U2gKM25XcFBCVjl4aUtab21PQ1FXeENzMjFLZnZ2VG9hQUdUWkhpM09rOWZJWlZ3K1Z6MVdsSnhHamttcnlsNlRHQwpsRmxqNXZaTURVdFEKLS0tIENnUDdTOW1PR3pRa2RRb0ZDanVVRkt0bkV1aVFLYnpGbmI1dnRDeE5rL28KYFXZk5Z8plrNygX/RItL/99oNEOW5Mqb7XEhh+YcZKIXD8xdQw3sxuYpwK8kDGirMG8fmxEE8g8FOJ00Clm47CPqxQ4Z14d97kTwljHNsdf29/kBfeQXuPK9hO0=";
        };
        CACHIX_AUTH_TOKEN = {
          provider = "age";
          value = "YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBJTzlhQkRmUmlCSDBhTWNiV1VBaGVXcmU5UGkvYXZZSWFGeWlCdVNFTXhzCitWZThweW15RW5OMFBrSk02OStPMXc1a2oreEFaWFByaUNHS1dxUjU1YWMKLT4gfDp5MC1ncmVhc2UgJHEge294YyB8IExTRDY0CjdaY0trZEFVY2diWHhON1ZKMjY1OEVwVHYxSEpxT2RBTXRweEx3MStkalhObHVQWkZHRzFBanhwMzhKcjlzQ0YKSVB4a2NKQmRSQk1TdmgrNnlyUWFKZmJkTVRRCi0tLSB3SFRLb2tseUk5dWdKOFlCbE5SRkljT1pWV2tlVTREcFRtQmRBNm9US3g0CgfPgRp7r7ol/HFAxzaYgjj7pajbN1HbiNW62PXCr6Aj3pVexK3F7U7vynPy5C9DjSV7Go7rxHEFFYmI3mRP0bGuti3pG/VbpeHXglvZaBrQSEE2ebIrx5/KbXaRGB6oqX/fR2lVvtoomGIX3dJnuzvBJvYwOJMQf8G1QhwtV0pff2Nm0u0UIiRao5nr+fnZM2kws3n3Euxo1HGhar0BpyWioSaC55a5Y6A2piiYeJbsRw==";
        };
      };
    };
  };
}
