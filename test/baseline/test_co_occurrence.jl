function test_co_occurrence()
    println("-- Testing CoOccurrence recommender")

    da = DataAccessor(sparse([1 0 0; 4 5 0]))
    recommender = CoOccurrence(da, Parameters(:i_ref => 1))
    build(recommender)
    @test ranking(recommender, 1, 1) == 100.0
    @test ranking(recommender, 1, 2) == 50.0
    @test ranking(recommender, 1, 3) == 0.0
end

test_co_occurrence()
