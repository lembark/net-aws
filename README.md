# net-aws
AWS API and Utility modules.

This is a replacement for the Net::Amazon modules, starting with 
Glacier, using a seprate low-level API module and higher-level 
Vault for composite operations. The goal is to have most of the 
work via simple calls like "$vault->download_completed_jobs" rather
than force everyone to re-invent (or at least -write) the wheel
using the API.

I've also separated out the TreeHash functions and put them into 
simple functions using const vaules for a more FP-ish feel that
should prove easier to test; eventually the sig's will get similar
treatment.

At this point please still consider this code alpha; any feedback
on the functionality provided by the Glacier::Vault module would
be appreciated.
