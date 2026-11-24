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
        GITHUB_ENTERPRISE_HOST = {
          provider = "age";
          value = "YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSB3eElEaFczWEFWOHZlWElDY3VBcWd6a0k0WlRmU2kvNHdFSlFHbU8xZ0ZnCnB6Q0tYaEJ6dFZuOFViYm1uK2F0YVNDOCs1RHN3b3NOa2lhQXNQU2ZWVDQKLT4gSkpNNkErYS1ncmVhc2UgPygKVHdZZ0E5WkE4TEtUaEszd3lMZUtmTGM4SE9nRXUzSlZjVGNxQkNxQ3FhQlFSK0Y0NXNxRGpSTEZZV0dRd21Qcwpkd1ovUlhsMVVBdERXNGtnTHNLNW5QZXljZnRvT1dnRS9VaUUxa0VaenZrK2R1NXNKVmtLWVNKOQotLS0gRFE1TjJMUlVUL1V1SDZUenJvZGQ1UTFERDBhMnZNM2tVR3VwUzdsaXVLQQqi0xYIriwXvd6LexMf18yvsKVHgquq9fR+Y0w7W1fcGy3Hz1KDZk0jTLLGjj8+6JQUzNSphA==";
        };
        DOPPLER_TOKEN = {
          provider = "age";
          value = "YWdlLWVuY3J5cHRpb24ub3JnL3YxCi0+IFgyNTUxOSBkRXN2U2NMdm84THVNdkxoa3YvK3IyU1UwOGpjK0sxLzV3aHBqN2hOZG1zCjJUVTQvM1piWm8zTVZ3eHhOOUY3K3ZMRjViSjBwNWVpM0Z1alRXS2dBZjgKLT4gUC1ncmVhc2UgcmBgd1Q3ICxaLikzLkcgYlBzYTkgYiFJSWgKYzAvS01ldEltVFZmOEk0WEVUcHRkUGcKLS0tIE5LWUZ0VysyTFlqWTdwWlJLWkNOaVM3bWZQNUYvcUFkcldsb2VuakhBQlkKk9tAASW5dG8o4YhzeWZJtf1ccyufSj6Irgde9T5xo3y6cmlj3asatuo5XOb/lZcERc1JA8dFo5qRKqrhJHbH2pK3uSwOBc+3oc1X2XofvYxH";
        };
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
