#include "mex.h"
#include "cokus.cpp"

// Syntax
//   [ WP , DP , Z ] = GibbsSamplerLDA( WS , DS , T , N , ALPHA , BETA , SEED , OUTPUT )

// Syntax
//   [ WP , DP , Z ] = GibbsSamplerLDA( WS , DS , T , N , ALPHA , BETA , SEED , OUTPUT , ZIN )

// Updated for 64-bit compilers

void GibbsSamplerLDA( double ALPHA, double BETA, int W, int T, int D, int NN, int OUTPUT, int n, int *z, int *d, int *w, int *wp, int *dp, int *ztot, int *order, double *probs, int startcond )
{
  int wi,di,i,ii,j,topic, rp, temp, iter, wioffset, dioffset;
  double totprob, WBETA, r, max;

  if (startcond == 1) {
      /* start from previously saved state */
      for (i=0; i<n; i++)
      {
          wi = w[ i ];
          di = d[ i ];
          topic = z[ i ];
          wp[ wi*T + topic ]++; // increment wp count matrix
          dp[ di*T + topic ]++; // increment dp count matrix
          ztot[ topic ]++; // increment ztot matrix
      }
  }
  
  if (startcond == 0) {
  /* random initialization */
      if (OUTPUT==2) mexPrintf( "Starting Random initialization\n" );
      for (i=0; i<n; i++)
      {
          wi = w[ i ];
          di = d[ i ];
          // pick a random topic 0..T-1
          topic = (int) ( (double) randomMT() * (double) T / (double) (4294967296.0 + 1.0) );
          z[ i ] = topic; // assign this word token to this topic
          wp[ wi*T + topic ]++; // increment wp count matrix
          dp[ di*T + topic ]++; // increment dp count matrix
          ztot[ topic ]++; // increment ztot matrix
      }
  }
  
  if (OUTPUT==2) mexPrintf( "Determining random order update sequence\n" );
  
  for (i=0; i<n; i++) order[i]=i; // fill with increasing series
  for (i=0; i<(n-1); i++) {
      // pick a random integer between i and nw
      rp = i + (int) ((double) (n-i) * (double) randomMT() / (double) (4294967296.0 + 1.0));
      
      // switch contents on position i and position rp
      temp = order[rp];
      order[rp]=order[i];
      order[i]=temp;
  }
  
  //for (i=0; i<n; i++) mexPrintf( "i=%3d order[i]=%3d\n" , i , order[ i ] );
  WBETA = (double) (W*BETA);
  for (iter=0; iter<NN; iter++) {
      if (OUTPUT >=1) {
          if ((iter % 10)==0) mexPrintf( "\tIteration %d of %d\n" , iter , NN );
          if ((iter % 10)==0) mexEvalString("drawnow;");
      }
      for (ii = 0; ii < n; ii++) {
          i = order[ ii ]; // current word token to assess
          
          wi  = w[i]; // current word index
          di  = d[i]; // current document index  
          topic = z[i]; // current topic assignment to word token
          ztot[topic]--;  // substract this from counts
          
          wioffset = wi*T;
          dioffset = di*T;
          
          wp[wioffset+topic]--;
          dp[dioffset+topic]--;
          
          //mexPrintf( "(1) Working on ii=%d i=%d wi=%d di=%d topic=%d wp=%d dp=%d\n" , ii , i , wi , di , topic , wp[wi+topic*W] , dp[wi+topic*D] );
          
          totprob = (double) 0;
          for (j = 0; j < T; j++) {
              probs[j] = ((double) wp[ wioffset+j ] + (double) BETA)/( (double) ztot[j]+ (double) WBETA)*( (double) dp[ dioffset+ j ] + (double) ALPHA);
              totprob += probs[j];
          }
          
          // sample a topic from the distribution
          r = (double) totprob * (double) randomMT() / (double) 4294967296.0;
          max = probs[0];
          topic = 0;
          while (r>max) {
              topic++;
              max += probs[topic];
          }
           
          z[i] = topic; // assign current word token i to topic j
          wp[wioffset + topic ]++; // and update counts
          dp[dioffset + topic ]++;
          ztot[topic]++;
          
          //mexPrintf( "(2) Working on ii=%d i=%d wi=%d di=%d topic=%d wp=%d dp=%d\n" , ii , i , wi , di , topic , wp[wi+topic*W] , dp[wi+topic*D] );
      }
  }
}

void mexFunction(int nlhs, mxArray *plhs[], int nrhs,
                 const mxArray *prhs[])
{
  double *srwp, *srdp, *probs, *Z, *WS, *DS, *ZIN;
  double ALPHA,BETA;
  mwIndex *irwp, *jcwp, *irdp, *jcdp;
  int *z,*d,*w, *order, *wp, *dp, *ztot;
  int W,T,D,NN,SEED,OUTPUT, nzmax, nzmaxwp, nzmaxdp, ntokens;
  int i,j,c,n,nt,wi,di, startcond;
  
  /* Check for proper number of arguments. */
  if (nrhs < 8) {
    mexErrMsgTxt("At least 8 input arguments required");
  } else if (nlhs < 3) {
    mexErrMsgTxt("3 output arguments required");
  }
  
  startcond = 0;
  if (nrhs == 9) startcond = 1;
  
  /* process the input arguments */
  if (mxIsDouble( prhs[ 0 ] ) != 1) mexErrMsgTxt("WS input vector must be a double precision matrix");
  if (mxIsDouble( prhs[ 1 ] ) != 1) mexErrMsgTxt("DS input vector must be a double precision matrix");
  
  // pointer to word indices
  WS = mxGetPr( prhs[ 0 ] );
     
  // pointer to document indices
  DS = mxGetPr( prhs[ 1 ] );
  
  // get the number of tokens
  ntokens = mxGetM( prhs[ 0 ] ) * mxGetN( prhs[ 0 ] );
  
  
  if (ntokens == 0) mexErrMsgTxt("WS vector is empty"); 
  if (ntokens != ( mxGetM( prhs[ 1 ] ) * mxGetN( prhs[ 1 ] ))) mexErrMsgTxt("WS and DS vectors should have same number of entries");
  
  T    = (int) mxGetScalar(prhs[2]);
  if (T<=0) mexErrMsgTxt("Number of topics must be greater than zero");
  
  NN    = (int) mxGetScalar(prhs[3]);
  if (NN<0) mexErrMsgTxt("Number of iterations must be positive");
  
  ALPHA = (double) mxGetScalar(prhs[4]);
  if (ALPHA<=0) mexErrMsgTxt("ALPHA must be greater than zero");
  
  BETA = (double) mxGetScalar(prhs[5]);
  if (BETA<=0) mexErrMsgTxt("BETA must be greater than zero");
  
  SEED = (int) mxGetScalar(prhs[6]);
  
  OUTPUT = (int) mxGetScalar(prhs[7]);
  
  if (startcond == 1) {
      ZIN = mxGetPr( prhs[ 8 ] );
      if (ntokens != ( mxGetM( prhs[ 8 ] ) * mxGetN( prhs[ 8 ] ))) mexErrMsgTxt("WS and ZIN vectors should have same number of entries");
  }
  
  // seeding
  seedMT( 1 + SEED * 2 ); // seeding only works on uneven numbers
  
   
  
/* allocate memory */
  z  = (int *) mxCalloc( ntokens , sizeof( int ));
  
  if (startcond == 1) {
     for (i=0; i<ntokens; i++) z[ i ] = (int) ZIN[ i ] - 1;   
  }
  
  d  = (int *) mxCalloc( ntokens , sizeof( int ));
  w  = (int *) mxCalloc( ntokens , sizeof( int ));
  order  = (int *) mxCalloc( ntokens , sizeof( int ));  
  ztot  = (int *) mxCalloc( T , sizeof( int ));
  probs  = (double *) mxCalloc( T , sizeof( double ));
  
  // copy over the word and document indices into internal format
  for (i=0; i<ntokens; i++) {
     w[ i ] = (int) WS[ i ] - 1;
     d[ i ] = (int) DS[ i ] - 1;
  }
  
  n = ntokens;
  
  W = 0;
  D = 0;
  for (i=0; i<n; i++) {
     if (w[ i ] > W) W = w[ i ];
     if (d[ i ] > D) D = d[ i ];
  }
  W = W + 1;
  D = D + 1;
  
  wp  = (int *) mxCalloc( T*W , sizeof( int ));
  dp  = (int *) mxCalloc( T*D , sizeof( int ));
   
  //mexPrintf( "N=%d  T=%d W=%d D=%d\n" , ntokens , T , W , D );
  
  if (OUTPUT==2) {
      mexPrintf( "Running LDA Gibbs Sampler Version 1.0\n" );
      if (startcond==1) mexPrintf( "Starting from previous state ZIN\n" );
      mexPrintf( "Arguments:\n" );
      mexPrintf( "\tNumber of words      W = %d\n"    , W );
      mexPrintf( "\tNumber of docs       D = %d\n"    , D );
      mexPrintf( "\tNumber of topics     T = %d\n"    , T );
      mexPrintf( "\tNumber of iterations N = %d\n"    , NN );
      mexPrintf( "\tHyperparameter   ALPHA = %4.4f\n" , ALPHA );
      mexPrintf( "\tHyperparameter    BETA = %4.4f\n" , BETA );
      mexPrintf( "\tSeed number            = %d\n"    , SEED );
      mexPrintf( "\tNumber of tokens       = %d\n"    , ntokens );
      mexPrintf( "Internal Memory Allocation\n" );
      mexPrintf( "\tw,d,z,order indices combined = %d bytes\n" , 4 * sizeof( int) * ntokens );
      mexPrintf( "\twp (full) matrix = %d bytes\n" , sizeof( int ) * W * T  );
      mexPrintf( "\tdp (full) matrix = %d bytes\n" , sizeof( int ) * D * T  );
      //mexPrintf( "Checking: sizeof(int)=%d sizeof(long)=%d sizeof(double)=%d\n" , sizeof(int) , sizeof(long) , sizeof(double));
  }
  
  /* run the model */
  GibbsSamplerLDA( ALPHA, BETA, W, T, D, NN, OUTPUT, n, z, d, w, wp, dp, ztot, order, probs, startcond );
  
  /* convert the full wp matrix into a sparse matrix */
  nzmaxwp = 0;
  for (i=0; i<W; i++) {
     for (j=0; j<T; j++)
         nzmaxwp += (int) ( *( wp + j + i*T )) > 0;
  }  
  /*if (OUTPUT==2) {
      mexPrintf( "Constructing sparse output matrix wp\n" );
      mexPrintf( "Number of nonzero entries for WP = %d\n" , nzmaxwp );
  }*/
  
  // MAKE THE WP SPARSE MATRIX
  plhs[0] = mxCreateSparse( W,T,nzmaxwp,mxREAL);
  srwp  = mxGetPr(plhs[0]);
  irwp = mxGetIr(plhs[0]);
  jcwp = mxGetJc(plhs[0]);  
  n = 0;
  for (j=0; j<T; j++) {
      *( jcwp + j ) = n;
      for (i=0; i<W; i++) {
         c = (int) *( wp + i*T + j );
         if (c >0) {
             *( srwp + n ) = c;
             *( irwp + n ) = i;
             n++;
         }
      }    
  }  
  *( jcwp + T ) = n;    
   
  // MAKE THE DP SPARSE MATRIX
  nzmaxdp = 0;
  for (i=0; i<D; i++) {
      for (j=0; j<T; j++)
          nzmaxdp += (int) ( *( dp + j + i*T )) > 0;
  }  
  /*if (OUTPUT==2) {
      mexPrintf( "Constructing sparse output matrix dp\n" );
      mexPrintf( "Number of nonzero entries for DP = %d\n" , nzmaxdp );
  } */ 
  plhs[1] = mxCreateSparse( D,T,nzmaxdp,mxREAL);
  srdp  = mxGetPr(plhs[1]);
  irdp = mxGetIr(plhs[1]);
  jcdp = mxGetJc(plhs[1]);
  n = 0;
  for (j=0; j<T; j++) {
      *( jcdp + j ) = n;
      for (i=0; i<D; i++) {
          c = (int) *( dp + i*T + j );
          if (c >0) {
              *( srdp + n ) = c;
              *( irdp + n ) = i;
              n++;
          }
      }
  }
  *( jcdp + T ) = n;
  
  plhs[ 2 ] = mxCreateDoubleMatrix( 1,ntokens , mxREAL );
  Z = mxGetPr( plhs[ 2 ] );
  for (i=0; i<ntokens; i++) Z[ i ] = (double) z[ i ] + 1;
}
