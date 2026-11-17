-- Same call, same priming. With the (Status, ShippingCity) index the plan is right for every value.
EXEC dbo.GetStatusSummary @Status = 4;
